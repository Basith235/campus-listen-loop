-- Create enum for user roles
CREATE TYPE public.user_role AS ENUM ('student', 'staff', 'admin');

-- Create enum for complaint categories
CREATE TYPE public.complaint_category AS ENUM ('hostel', 'academic', 'food', 'infrastructure', 'other');

-- Create enum for complaint severity
CREATE TYPE public.complaint_severity AS ENUM ('low', 'medium', 'high');

-- Create enum for complaint status
CREATE TYPE public.complaint_status AS ENUM ('submitted', 'in_progress', 'resolved');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  role user_role NOT NULL DEFAULT 'student',
  hostel TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Create complaints table
CREATE TABLE public.complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category complaint_category NOT NULL,
  severity complaint_severity NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
  status complaint_status NOT NULL DEFAULT 'submitted',
  staff_assigned UUID REFERENCES public.profiles(id),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMP WITH TIME ZONE,
  withdrawn_at TIMESTAMP WITH TIME ZONE,
  withdrawal_reason TEXT
);

-- Enable RLS on complaints
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- Complaint policies
CREATE POLICY "Students can view their own complaints"
  ON public.complaints FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "Students can create complaints"
  ON public.complaints FOR INSERT
  WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Students can update their own complaints"
  ON public.complaints FOR UPDATE
  USING (auth.uid() = student_id);

-- Create timeline table for tracking updates
CREATE TABLE public.complaint_timeline (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  updated_by UUID REFERENCES public.profiles(id),
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enable RLS on timeline
ALTER TABLE public.complaint_timeline ENABLE ROW LEVEL SECURITY;

-- Timeline policies
CREATE POLICY "Users can view timeline for their complaints"
  ON public.complaint_timeline FOR SELECT
  USING (
    complaint_id IN (
      SELECT id FROM public.complaints WHERE student_id = auth.uid()
    )
  );

-- Create function to automatically add user to profiles on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Student'),
    NEW.email,
    'student'
  );
  RETURN NEW;
END;
$$;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger for profiles updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Function to add timeline entry when complaint is created
CREATE OR REPLACE FUNCTION public.add_complaint_timeline()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.complaint_timeline (complaint_id, updated_by, message)
  VALUES (NEW.id, NEW.student_id, 'Complaint submitted');
  RETURN NEW;
END;
$$;

-- Trigger to add timeline on complaint creation
CREATE TRIGGER on_complaint_created
  AFTER INSERT ON public.complaints
  FOR EACH ROW
  EXECUTE FUNCTION public.add_complaint_timeline();

-- Function to check active complaint limit (max 3)
CREATE OR REPLACE FUNCTION public.check_active_complaint_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
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

-- Trigger to enforce complaint limit
CREATE TRIGGER enforce_complaint_limit
  BEFORE INSERT ON public.complaints
  FOR EACH ROW
  EXECUTE FUNCTION public.check_active_complaint_limit();