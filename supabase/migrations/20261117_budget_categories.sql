-- Applied to the expense-tracker project on 2026-11-17.
-- Six budgeted categories with carryover and spreading, without rewriting old entries.

-- Retired categories point at the category they now count toward; entries keep their original category_id
alter table categories
  add column rolls_into integer references categories(id),
  add column archived boolean not null default false,
  add column sort_order integer;

-- Budgets are dated so changing one later doesn't rewrite past carryover
create table category_budgets (
  id serial primary key,
  category_id integer not null references categories(id),
  starts_month date not null check (extract(day from starts_month) = 1),
  amount numeric not null check (amount >= 0),
  unique (category_id, starts_month)
);
alter table category_budgets enable row level security;
create policy "Allow access to authenticated users only" on category_budgets
  for all to authenticated using (true) with check (true);

-- Spreading: an entry counts amount / spread_months in each month from spread_start
alter table line_items
  add column spread_start date check (spread_start is null or extract(day from spread_start) = 1),
  add column spread_months integer check (spread_months is null or spread_months between 1 and 36);

-- New categories (Generosity stays as is)
insert into categories (name, want_need, sort_order) values
  ('Groceries', 'Need', 1),
  ('Eating Out', 'Want', 2),
  ('Personal Treats', 'Want', 3),
  ('Other Needs', 'Need', 4),
  ('Experiences', 'Want', 6);
update categories set sort_order = 5 where name = 'Generosity';

-- Retire the old ones
update categories o set archived = true, rolls_into = n.id
from categories n
where (o.name, n.name) in (
  ('Food - necessary', 'Groceries'),
  ('Food - social', 'Eating Out'),
  ('Travel - necessary', 'Other Needs'),
  ('Travel - social', 'Experiences'),
  ('Lifestyle', 'Other Needs'),
  ('Major Experiences', 'Experiences'),
  ('Other - necessary', 'Other Needs'),
  ('Other - discretionary', 'Personal Treats')
);

-- Merchant rules should suggest active categories
update merchant_rules r set default_category_id = c.rolls_into
from categories c where c.id = r.default_category_id and c.rolls_into is not null;

-- Budgets from November 2026 (Other Needs has none)
insert into category_budgets (category_id, starts_month, amount)
select id, date '2026-11-01', b.amount from categories
join (values ('Groceries', 200), ('Eating Out', 300), ('Personal Treats', 100),
             ('Generosity', 300), ('Experiences', 300)) as b(name, amount) using (name);

-- One-off fixes requested at the same time
update line_items set category_id = (select id from categories where name = 'Other Needs') where id in (177, 179); -- copay, meds
update line_items set category_id = (select id from categories where name = 'Eating Out') where id = 53;           -- Waymo to bday dinner
update line_items set category_id = (select id from categories where name = 'Experiences') where id = 36;          -- Concert parking

-- Follow-up the same day: fold Major Experiences entries into Experiences,
-- remaining Travel - social entries were eating out, Personal Treats budget raised to 150
update line_items set category_id = (select id from categories where name = 'Experiences')
  where category_id = (select id from categories where name = 'Major Experiences');
update line_items set category_id = (select id from categories where name = 'Eating Out')
  where id in (19, 70, 73, 141);  -- Gas, zipcar with athena, uber to la ong, uber to vic
update categories set rolls_into = (select id from categories where name = 'Eating Out') where name = 'Travel - social';
update category_budgets set amount = 150
  where category_id = (select id from categories where name = 'Personal Treats') and starts_month = '2026-11-01';
