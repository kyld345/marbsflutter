-- =============================================================
-- SUPABASE SQL FIXES  (run in Supabase → SQL Editor)
-- All fixes use the existing has_role() function from your schema.
-- =============================================================


-- ──────────────────────────────────────────────────────────────
-- FIX 1: Allow receptionists to assign the barber role
--
-- The existing function returns JSONB and only checks has_role('admin').
-- We keep RETURNS JSONB (can't change it with CREATE OR REPLACE)
-- and extend the check to include 'receptionist'.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_user_role(
  target_user_id UUID,
  new_role_name  TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_is_authorized BOOLEAN;
  target_role_id UUID;
  result JSONB;
BEGIN
  -- Allow both admins AND receptionists to assign roles
  SELECT has_role(ARRAY['admin', 'receptionist']) INTO caller_is_authorized;
  IF NOT caller_is_authorized THEN
    RAISE EXCEPTION 'Unauthorized: only admins or receptionists can assign roles';
  END IF;

  IF new_role_name NOT IN ('customer', 'barber', 'receptionist', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', new_role_name;
  END IF;

  SELECT id INTO target_role_id FROM public.roles WHERE name = new_role_name;
  IF target_role_id IS NULL THEN
    RAISE EXCEPTION 'Role not found: %', new_role_name;
  END IF;

  UPDATE public.users
  SET role_id = target_role_id, updated_at = now()
  WHERE id = target_user_id;

  SELECT jsonb_build_object(
    'success', true,
    'user_id', target_user_id,
    'role', new_role_name
  ) INTO result;

  RETURN result;
END;
$$;


-- ──────────────────────────────────────────────────────────────
-- FIX 2: Let receptionists insert/update/delete services
--        (existing policy "services_all_admin" is admin-only)
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "services_all_admin"       ON services;
DROP POLICY IF EXISTS "Staff can insert services" ON services;
DROP POLICY IF EXISTS "Staff can update services" ON services;
DROP POLICY IF EXISTS "Staff can delete services" ON services;

CREATE POLICY "services_all_staff" ON services FOR ALL
  USING     (has_role(ARRAY['admin', 'receptionist']))
  WITH CHECK (has_role(ARRAY['admin', 'receptionist']));


-- ──────────────────────────────────────────────────────────────
-- FIX 3: Schedules — ensure INSERT is allowed for staff
--        (existing policy uses FOR ALL but no WITH CHECK,
--         which may block inserts on some Postgres versions)
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "schedules_admin_all"          ON schedules;
DROP POLICY IF EXISTS "Staff can manage schedules"   ON schedules;

CREATE POLICY "schedules_staff_all" ON schedules FOR ALL
  USING     (has_role(ARRAY['admin', 'receptionist']))
  WITH CHECK (has_role(ARRAY['admin', 'receptionist']));

-- Keep barber's own-schedule policy (drop & recreate to avoid conflicts)
DROP POLICY IF EXISTS "schedules_barber_own"              ON schedules;
DROP POLICY IF EXISTS "Barbers can manage own schedule"   ON schedules;

CREATE POLICY "schedules_barber_own" ON schedules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.barbers b
      WHERE b.id = schedules.barber_id AND b.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.barbers b
      WHERE b.id = schedules.barber_id AND b.user_id = auth.uid()
    )
  );


-- ──────────────────────────────────────────────────────────────
-- FIX 4: Staff can see ALL appointments
--        (so barber/receptionist/admin can view customer bookings)
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Staff can view all appointments"   ON appointments;
DROP POLICY IF EXISTS "Staff can insert appointments"     ON appointments;
DROP POLICY IF EXISTS "Staff can update appointments"     ON appointments;

-- Staff read-all
CREATE POLICY "appointments_staff_select" ON appointments FOR SELECT
  USING (has_role(ARRAY['admin', 'receptionist', 'barber']));

-- Staff can create walk-in appointments
CREATE POLICY "appointments_staff_insert" ON appointments FOR INSERT
  WITH CHECK (has_role(ARRAY['admin', 'receptionist', 'barber']));

-- Staff can update status
CREATE POLICY "appointments_staff_update" ON appointments FOR UPDATE
  USING     (has_role(ARRAY['admin', 'receptionist', 'barber']))
  WITH CHECK (has_role(ARRAY['admin', 'receptionist', 'barber']));
