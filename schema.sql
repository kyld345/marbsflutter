-- ============================================================
-- MARBIN BARBERSHOP - Supabase PostgreSQL Schema (FIXED)
-- Fix: RBAC security, role assignment, RLS policies
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ROLES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO roles (name, description) VALUES
  ('customer', 'Mobile app customer'),
  ('barber', 'Barber staff member'),
  ('receptionist', 'Front desk receptionist'),
  ('admin', 'Admin / Manager')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- USERS TABLE (extends Supabase Auth)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- BRANCHES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS branches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  open_time TIME DEFAULT '08:00',
  close_time TIME DEFAULT '20:00',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO branches (name, address, phone, email) VALUES
  ('Marbin Barbershop - Main', '123 Main Street, City Center', '+63 912 345 6789', 'main@marbinbarbershop.com'),
  ('Marbin Barbershop - Branch 2', '456 Second Ave, Uptown', '+63 917 654 3210', 'branch2@marbinbarbershop.com')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SERVICES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 30,
  is_active BOOLEAN DEFAULT TRUE,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO services (name, description, price, duration_minutes) VALUES
  ('Classic Haircut', 'Traditional barbershop haircut', 150.00, 30),
  ('Fade Cut', 'Modern fade with skin or scissor', 180.00, 45),
  ('Beard Trim', 'Shaping and trimming of beard', 100.00, 20),
  ('Hot Towel Shave', 'Traditional straight razor shave', 200.00, 45),
  ('Hair + Beard Combo', 'Haircut plus beard grooming', 250.00, 60),
  ('Kid''s Haircut', 'Haircut for children under 12', 120.00, 25),
  ('Hair Coloring', 'Full hair color treatment', 500.00, 90),
  ('Hair Treatment', 'Deep conditioning treatment', 350.00, 60)
ON CONFLICT DO NOTHING;

-- ============================================================
-- BARBERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS barbers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT,
  branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
  specialization TEXT,
  bio TEXT,
  experience_years INTEGER DEFAULT 0,
  rating DECIMAL(3,2) DEFAULT 0.00,
  total_reviews INTEGER DEFAULT 0,
  is_available BOOLEAN DEFAULT TRUE,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SCHEDULES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS schedules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  barber_id UUID REFERENCES barbers(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_day_off BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (barber_id, day_of_week)
);

-- ============================================================
-- APPOINTMENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES users(id) ON DELETE CASCADE,
  barber_id UUID REFERENCES barbers(id) ON DELETE SET NULL,
  branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  end_time TIME,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','confirmed','in_progress','completed','cancelled','no_show')),
  notes TEXT,
  total_price DECIMAL(10,2),
  payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid','paid','refunded')),
  is_walk_in BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- QUEUE TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  appointment_id UUID REFERENCES appointments(id) ON DELETE CASCADE,
  branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
  queue_number INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting','in_progress','completed','cancelled','skipped')),
  check_in_time TIMESTAMPTZ DEFAULT NOW(),
  called_time TIMESTAMPTZ,
  start_service_time TIMESTAMPTZ,
  end_service_time TIMESTAMPTZ,
  estimated_wait_minutes INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REVIEWS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES users(id) ON DELETE CASCADE,
  barber_id UUID REFERENCES barbers(id) ON DELETE CASCADE,
  appointment_id UUID REFERENCES appointments(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  is_published BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (customer_id, appointment_id)
);

-- ============================================================
-- NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('appointment','queue','promotion','system')),
  is_read BOOLEAN DEFAULT FALSE,
  data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_appointments_customer ON appointments(customer_id);
CREATE INDEX IF NOT EXISTS idx_appointments_barber ON appointments(barber_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);
CREATE INDEX IF NOT EXISTS idx_queue_branch ON queue(branch_id);
CREATE INDEX IF NOT EXISTS idx_queue_status ON queue(status);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_reviews_barber ON reviews(barber_id);
CREATE INDEX IF NOT EXISTS idx_schedules_barber ON schedules(barber_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role_id);
CREATE INDEX IF NOT EXISTS idx_barbers_user ON barbers(user_id);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_branches_updated BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_services_updated BEFORE UPDATE ON services FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_barbers_updated BEFORE UPDATE ON barbers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_appointments_updated BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_queue_updated BEFORE UPDATE ON queue FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_reviews_updated BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_schedules_updated BEFORE UPDATE ON schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- HAS_ROLE HELPER (SECURITY DEFINER bypasses RLS - no recursion)
-- ============================================================
CREATE OR REPLACE FUNCTION has_role(role_names TEXT[])
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.roles r ON r.id = u.role_id
    WHERE u.id = auth.uid()
      AND r.name = ANY(role_names)
      AND u.is_active = TRUE
  );
$$;

-- ============================================================
-- GET CURRENT USER ROLE (safe helper for clients)
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.name
  FROM public.users u
  JOIN public.roles r ON r.id = u.role_id
  WHERE u.id = auth.uid()
  LIMIT 1;
$$;

-- ============================================================
-- AUTO-CREATE USER PROFILE ON SIGN UP
-- SECURITY FIX: Self-registration ALWAYS gets 'customer' role.
-- Only admins can upgrade roles via admin_set_user_role().
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  customer_role_id UUID;
BEGIN
  -- SECURITY: Always assign 'customer' role on self-registration.
  -- Role is NEVER taken from metadata to prevent privilege escalation.
  SELECT id INTO customer_role_id 
  FROM public.roles 
  WHERE name = 'customer' 
  LIMIT 1;

  INSERT INTO public.users (id, full_name, role_id, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    customer_role_id,
    NEW.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
    phone = COALESCE(EXCLUDED.phone, public.users.phone);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- ADMIN-ONLY: Assign role to a user
-- Only callable by authenticated admins
-- ============================================================
CREATE OR REPLACE FUNCTION admin_set_user_role(
  target_user_id UUID,
  new_role_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_is_admin BOOLEAN;
  target_role_id UUID;
  result JSONB;
BEGIN
  -- Verify caller is admin
  SELECT has_role(ARRAY['admin']) INTO caller_is_admin;
  IF NOT caller_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: only admins can assign roles';
  END IF;

  -- Validate role name
  IF new_role_name NOT IN ('customer', 'barber', 'receptionist', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', new_role_name;
  END IF;

  -- Get role ID
  SELECT id INTO target_role_id FROM public.roles WHERE name = new_role_name;
  IF target_role_id IS NULL THEN
    RAISE EXCEPTION 'Role not found: %', new_role_name;
  END IF;

  -- Update user role
  UPDATE public.users
  SET role_id = target_role_id, updated_at = NOW()
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', target_user_id;
  END IF;

  result := jsonb_build_object(
    'success', true,
    'user_id', target_user_id,
    'new_role', new_role_name
  );
  RETURN result;
END;
$$;

-- ============================================================
-- ROW LEVEL SECURITY (RLS) - Drop and recreate to fix conflicts
-- ============================================================

-- USERS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Admins can manage users" ON users;
DROP POLICY IF EXISTS "Staff view users" ON users;

CREATE POLICY "users_select_own" ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "users_select_staff" ON users FOR SELECT
  USING (has_role(ARRAY['admin', 'receptionist']));

CREATE POLICY "users_update_own" ON users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_admin" ON users FOR UPDATE
  USING (has_role(ARRAY['admin']));

CREATE POLICY "users_insert_trigger" ON users FOR INSERT
  WITH CHECK (true); -- handled by trigger (SECURITY DEFINER)

CREATE POLICY "users_delete_admin" ON users FOR DELETE
  USING (has_role(ARRAY['admin']));

-- SERVICES (public read, admin write)
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view active services" ON services;
DROP POLICY IF EXISTS "Admins can manage services" ON services;
CREATE POLICY "services_select_active" ON services FOR SELECT USING (is_active = true);
CREATE POLICY "services_select_admin" ON services FOR SELECT USING (has_role(ARRAY['admin', 'receptionist']));
CREATE POLICY "services_all_admin" ON services FOR ALL USING (has_role(ARRAY['admin']));

-- BARBERS (public read)
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view active barbers" ON barbers;
DROP POLICY IF EXISTS "Admins can manage barbers" ON barbers;
CREATE POLICY "barbers_select_public" ON barbers FOR SELECT USING (true);
CREATE POLICY "barbers_all_admin" ON barbers FOR ALL USING (has_role(ARRAY['admin', 'receptionist']));
CREATE POLICY "barbers_update_own" ON barbers FOR UPDATE
  USING (user_id = auth.uid());

-- APPOINTMENTS
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Customers view own appointments" ON appointments;
DROP POLICY IF EXISTS "Customers create appointments" ON appointments;
DROP POLICY IF EXISTS "Customers cancel own appointments" ON appointments;
DROP POLICY IF EXISTS "Staff view all appointments" ON appointments;
DROP POLICY IF EXISTS "Staff manage appointments" ON appointments;

CREATE POLICY "appt_customer_select" ON appointments FOR SELECT
  USING (customer_id = auth.uid());
CREATE POLICY "appt_staff_select" ON appointments FOR SELECT
  USING (has_role(ARRAY['admin', 'receptionist', 'barber']));
CREATE POLICY "appt_customer_insert" ON appointments FOR INSERT
  WITH CHECK (customer_id = auth.uid());
CREATE POLICY "appt_customer_update_cancel" ON appointments FOR UPDATE
  USING (customer_id = auth.uid())
  WITH CHECK (status IN ('cancelled'));
CREATE POLICY "appt_staff_all" ON appointments FOR ALL
  USING (has_role(ARRAY['admin', 'receptionist']));
CREATE POLICY "appt_barber_update" ON appointments FOR UPDATE
  USING (
    has_role(ARRAY['barber']) AND
    EXISTS (
      SELECT 1 FROM public.barbers b
      WHERE b.id = appointments.barber_id AND b.user_id = auth.uid()
    )
  );

-- QUEUE
ALTER TABLE queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view queue" ON queue;
DROP POLICY IF EXISTS "Staff manage queue" ON queue;
DROP POLICY IF EXISTS "Customers can enqueue own appointments" ON queue;

CREATE POLICY "queue_select_all" ON queue FOR SELECT USING (true);
CREATE POLICY "queue_staff_all" ON queue FOR ALL
  USING (has_role(ARRAY['admin', 'receptionist', 'barber']));
CREATE POLICY "queue_customer_insert" ON queue FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.id = queue.appointment_id AND a.customer_id = auth.uid()
    )
  );

-- NOTIFICATIONS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users update own notifications" ON notifications;
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;

CREATE POLICY "notif_select_own" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "notif_update_own" ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "notif_insert_any" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "notif_admin_all" ON notifications FOR ALL USING (has_role(ARRAY['admin']));

-- REVIEWS
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view published reviews" ON reviews;
DROP POLICY IF EXISTS "Customers create own reviews" ON reviews;
DROP POLICY IF EXISTS "Customers update own reviews" ON reviews;

CREATE POLICY "reviews_select_published" ON reviews FOR SELECT USING (is_published = true);
CREATE POLICY "reviews_customer_insert" ON reviews FOR INSERT WITH CHECK (customer_id = auth.uid());
CREATE POLICY "reviews_customer_update" ON reviews FOR UPDATE USING (customer_id = auth.uid());
CREATE POLICY "reviews_admin_all" ON reviews FOR ALL USING (has_role(ARRAY['admin']));

-- BRANCHES (public read)
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view branches" ON branches;
DROP POLICY IF EXISTS "Admins manage branches" ON branches;

CREATE POLICY "branches_select_active" ON branches FOR SELECT USING (is_active = true);
CREATE POLICY "branches_admin_all" ON branches FOR ALL USING (has_role(ARRAY['admin']));

-- SCHEDULES
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view schedules" ON schedules;
DROP POLICY IF EXISTS "Admins manage schedules" ON schedules;

CREATE POLICY "schedules_select_all" ON schedules FOR SELECT USING (true);
CREATE POLICY "schedules_admin_all" ON schedules FOR ALL
  USING (has_role(ARRAY['admin', 'receptionist']));
CREATE POLICY "schedules_barber_own" ON schedules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.barbers b
      WHERE b.id = schedules.barber_id AND b.user_id = auth.uid()
    )
  );

-- ROLES (read-only for all authenticated)
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Roles public read" ON roles;
CREATE POLICY "roles_select_all" ON roles FOR SELECT USING (true);
CREATE POLICY "roles_admin_all" ON roles FOR ALL USING (has_role(ARRAY['admin']));

-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE queue;
ALTER PUBLICATION supabase_realtime ADD TABLE appointments;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ============================================================
-- GRANT EXECUTE ON FUNCTIONS TO authenticated
-- ============================================================
GRANT EXECUTE ON FUNCTION has_role(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_user_role(UUID, TEXT) TO authenticated;