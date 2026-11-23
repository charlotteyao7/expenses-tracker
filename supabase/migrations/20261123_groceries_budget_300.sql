-- Applied to the expense-tracker project on 2026-11-23.
-- Groceries budget raised from 200 to 300, effective November 2026.
update category_budgets set amount = 300
  where category_id = (select id from categories where name = 'Groceries') and starts_month = '2026-11-01';
