-- 1) Create app_role enum for role-based access control
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
    CREATE TYPE public.app_role AS ENUM ('student', 'staff', 'admin');
  END IF;
END;
$$;

-- 2) Create user_roles table (roles are separated from profiles to avoid privilege escalation)
CREATE TABLE IF NOT EXISTS public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- 3) Create has_role() helper with SECURITY DEFINER and fixed search_path
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  );
$$;

-- 4) RLS policies for user_roles
-- Allow each user to see their own roles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_roles'
      AND policyname = 'Users can view their own roles'
  ) THEN
    CREATE POLICY "Users can view their own roles"
      ON public.user_roles
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id OR public.has_role(auth.uid(), 'admin'));
  END IF;
END;
$$;

-- Only admins can insert/update/delete roles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_roles'
      AND policyname = 'Admins manage user roles'
  ) THEN
    CREATE POLICY "Admins manage user roles"
      ON public.user_roles
      FOR ALL
      TO authenticated
      USING (public.has_role(auth.uid(), 'admin'))
      WITH CHECK (public.has_role(auth.uid(), 'admin'));
  END IF;
END;
$$;

-- 5) Remove insecure role column from profiles (roles now live in user_roles)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles DROP COLUMN role;
  END IF;
END;
$$;

-- 6) Add staff/admin access policies for complaints using has_role()
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'complaints'
      AND policyname = 'Staff can view assigned complaints'
  ) THEN
    CREATE POLICY "Staff can view assigned complaints"
      ON public.complaints
      FOR SELECT
      TO authenticated
      USING (
        public.has_role(auth.uid(), 'staff')
        AND staff_assigned = auth.uid()
      );
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'complaints'
      AND policyname = 'Staff can update assigned complaints'
  ) THEN
    CREATE POLICY "Staff can update assigned complaints"
      ON public.complaints
      FOR UPDATE
      TO authenticated
      USING (
        public.has_role(auth.uid(), 'staff')
        AND staff_assigned = auth.uid()
      )
      WITH CHECK (
        public.has_role(auth.uid(), 'staff')
        AND staff_assigned = auth.uid()
      );
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'complaints'
      AND policyname = 'Admin can view all complaints'
  ) THEN
    CREATE POLICY "Admin can view all complaints"
      ON public.complaints
      FOR SELECT
      TO authenticated
      USING (public.has_role(auth.uid(), 'admin'));
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'complaints'
      AND policyname = 'Admin can update all complaints'
  ) THEN
    CREATE POLICY "Admin can update all complaints"
      ON public.complaints
      FOR UPDATE
      TO authenticated
      USING (public.has_role(auth.uid(), 'admin'))
      WITH CHECK (public.has_role(auth.uid(), 'admin'));
  END IF;
END;
$$;

-- 7) Extend complaint_timeline policies so staff/admin can see relevant timelines
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'complaint_timeline'
      AND policyname = 'Staff can view timeline for assigned complaints'
  ) THEN
    CREATE POLICY "Staff can view timeline for assigned complaints"
      ON public.complaint_timeline
      FOR SELECT
      TO authenticated
      USING (
        public.has_role(auth.uid(), 'staff')
        AND complaint_id IN (
          SELECT id FROM public.complaints
          WHERE staff_assigned = auth.uid()
        )
      );
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'complaint_timeline'
      AND policyname = 'Admin can view all complaint timelines'
  ) THEN
    CREATE POLICY "Admin can view all complaint timelines"
      ON public.complaint_timeline
      FOR SELECT
      TO authenticated
      USING (public.has_role(auth.uid(), 'admin'));
  END IF;
END;
$$;

-- 8) Implement anonymous identity protection via identity_lockers
CREATE TABLE IF NOT EXISTS public.identity_lockers (
  complaint_id uuid PRIMARY KEY REFERENCES public.complaints(id) ON DELETE CASCADE,
  real_student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reveal_status text NOT NULL DEFAULT 'not_revealed',
  reveal_reason text,
  reveal_requested_by uuid REFERENCES public.profiles(id),
  revealed_at timestamptz
);

ALTER TABLE public.identity_lockers ENABLE ROW LEVEL SECURITY;

-- Only admins can access identity_lockers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'identity_lockers'
      AND policyname = 'Admin can manage identity lockers'
  ) THEN
    CREATE POLICY "Admin can manage identity lockers"
      ON public.identity_lockers
      FOR ALL
      TO authenticated
      USING (public.has_role(auth.uid(), 'admin'))
      WITH CHECK (public.has_role(auth.uid(), 'admin'));
  END IF;
END;
$$;

-- Function to create identity_locker entries for anonymous complaints
CREATE OR REPLACE FUNCTION public.create_identity_locker()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_anonymous THEN
    INSERT INTO public.identity_lockers (complaint_id, real_student_id)
    VALUES (NEW.id, NEW.student_id)
    ON CONFLICT (complaint_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger on complaints to populate identity_lockers for anonymous complaints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'on_anonymous_complaint'
  ) THEN
    CREATE TRIGGER on_anonymous_complaint
      AFTER INSERT ON public.complaints
      FOR EACH ROW
      WHEN (NEW.is_anonymous = true)
      EXECUTE FUNCTION public.create_identity_locker();
  END IF;
END;
$$;

-- 9) Fix function search_path warnings by setting search_path explicitly
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_active_complaint_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  active_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO active_count
  FROM public.complaints
  WHERE student_id = NEW.student_id
    AND status != 'resolved'
    AND withdrawn_at IS NULL;

  IF active_count >= 3 THEN
    RAISE EXCEPTION 'You cannot have more than 3 active complaints at a time';
  END IF;

  RETURN NEW;
END;
$$;