-- Roommate+ — wipe all test data
--
-- Removes every row from every app table but KEEPS the tables, columns,
-- indexes, and RLS policies. Run in Supabase Dashboard → SQL Editor.
--
-- TRUNCATE ... CASCADE clears children (history, items, users, join_codes)
-- automatically via foreign keys, but we list them explicitly for clarity.

truncate table
  public.expense_participants,
  public.expenses,
  public.history,
  public.items,
  public.join_codes,
  public.users,
  public.households
restart identity cascade;
