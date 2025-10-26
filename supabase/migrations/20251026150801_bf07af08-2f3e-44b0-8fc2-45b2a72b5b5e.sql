-- Create enum for user roles
CREATE TYPE public.app_role AS ENUM ('juiz', 'criador_processo', 'representante');

-- Create enum for judge types
CREATE TYPE public.judge_type AS ENUM ('eleitoral', 'crimes_desvios', 'geral');

-- Create enum for process status
CREATE TYPE public.process_status AS ENUM ('em_analise', 'aguardando_informacoes', 'julgado_sem_recurso', 'julgado_com_recurso', 'em_recurso', 'encerrado');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  judge_type judge_type,
  UNIQUE (user_id, role)
);

-- Create processes table
CREATE TABLE public.processes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_number TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  status process_status DEFAULT 'em_analise' NOT NULL,
  judge_type judge_type NOT NULL,
  creator_id UUID REFERENCES public.profiles(id) NOT NULL,
  judge_id UUID REFERENCES public.profiles(id),
  representative_id UUID REFERENCES public.profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create evidence table for uploaded documents
CREATE TABLE public.evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE NOT NULL,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_type TEXT NOT NULL,
  uploaded_by UUID REFERENCES public.profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create process_events table for tracking process history
CREATE TABLE public.process_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE NOT NULL,
  event_type TEXT NOT NULL,
  description TEXT NOT NULL,
  created_by UUID REFERENCES public.profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create additional_info_requests table
CREATE TABLE public.additional_info_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE NOT NULL,
  request_text TEXT NOT NULL,
  response_text TEXT,
  requested_by UUID REFERENCES public.profiles(id) NOT NULL,
  responded_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  responded_at TIMESTAMP WITH TIME ZONE
);

-- Create defenses table
CREATE TABLE public.defenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE NOT NULL,
  defense_text TEXT NOT NULL,
  created_by UUID REFERENCES public.profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create judgments table
CREATE TABLE public.judgments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE NOT NULL,
  judgment_text TEXT NOT NULL,
  has_appeal BOOLEAN DEFAULT FALSE NOT NULL,
  judge_id UUID REFERENCES public.profiles(id) NOT NULL,
  ai_suggestion TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create appeals table
CREATE TABLE public.appeals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE NOT NULL,
  judgment_id UUID REFERENCES public.judgments(id) ON DELETE CASCADE NOT NULL,
  appeal_text TEXT NOT NULL,
  created_by UUID REFERENCES public.profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.process_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.additional_info_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.defenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.judgments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;

-- Create security definer function to check user role
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Create function to get user role
CREATE OR REPLACE FUNCTION public.get_user_role(_user_id UUID)
RETURNS app_role
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.user_roles WHERE user_id = _user_id LIMIT 1
$$;

-- Create function to generate process number
CREATE OR REPLACE FUNCTION public.generate_process_number()
RETURNS TEXT
LANGUAGE PLPGSQL
AS $$
DECLARE
  year TEXT;
  sequence_num TEXT;
BEGIN
  year := TO_CHAR(NOW(), 'YYYY');
  sequence_num := LPAD((SELECT COUNT(*) + 1 FROM public.processes WHERE EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM NOW()))::TEXT, 6, '0');
  RETURN sequence_num || '/' || year;
END;
$$;

-- Create trigger function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$;

-- Create trigger for new user
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_processes_updated_at
  BEFORE UPDATE ON public.processes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS Policies for profiles
CREATE POLICY "Users can view all profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- RLS Policies for user_roles
CREATE POLICY "Users can view all roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (true);

-- RLS Policies for processes
CREATE POLICY "Users can view processes they're involved in"
  ON public.processes FOR SELECT
  TO authenticated
  USING (
    creator_id = auth.uid() OR
    judge_id = auth.uid() OR
    representative_id = auth.uid()
  );

CREATE POLICY "Criador de processo can create processes"
  ON public.processes FOR INSERT
  TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'criador_processo') AND creator_id = auth.uid());

CREATE POLICY "Juiz can update processes assigned to them"
  ON public.processes FOR UPDATE
  TO authenticated
  USING (public.has_role(auth.uid(), 'juiz') AND judge_id = auth.uid());

CREATE POLICY "Criador can update their processes"
  ON public.processes FOR UPDATE
  TO authenticated
  USING (public.has_role(auth.uid(), 'criador_processo') AND creator_id = auth.uid());

-- RLS Policies for evidence
CREATE POLICY "Users can view evidence for their processes"
  ON public.evidence FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = evidence.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

CREATE POLICY "Criador and Representante can insert evidence"
  ON public.evidence FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = evidence.process_id
      AND (processes.creator_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

-- RLS Policies for process_events
CREATE POLICY "Users can view events for their processes"
  ON public.process_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = process_events.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

CREATE POLICY "Users can create events for their processes"
  ON public.process_events FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = process_events.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    ) AND created_by = auth.uid()
  );

-- RLS Policies for additional_info_requests
CREATE POLICY "Users can view info requests for their processes"
  ON public.additional_info_requests FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = additional_info_requests.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid())
    )
  );

CREATE POLICY "Juiz can create info requests"
  ON public.additional_info_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    public.has_role(auth.uid(), 'juiz') AND requested_by = auth.uid()
  );

CREATE POLICY "Criador can update info requests"
  ON public.additional_info_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = additional_info_requests.process_id
      AND processes.creator_id = auth.uid()
    )
  );

-- RLS Policies for defenses
CREATE POLICY "Users can view defenses for their processes"
  ON public.defenses FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = defenses.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

CREATE POLICY "Representante can create defenses"
  ON public.defenses FOR INSERT
  TO authenticated
  WITH CHECK (
    public.has_role(auth.uid(), 'representante') AND created_by = auth.uid()
  );

-- RLS Policies for judgments
CREATE POLICY "Users can view judgments for their processes"
  ON public.judgments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = judgments.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

CREATE POLICY "Juiz can create judgments"
  ON public.judgments FOR INSERT
  TO authenticated
  WITH CHECK (
    public.has_role(auth.uid(), 'juiz') AND judge_id = auth.uid()
  );

-- RLS Policies for appeals
CREATE POLICY "Users can view appeals for their processes"
  ON public.appeals FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.processes
      WHERE processes.id = appeals.process_id
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

CREATE POLICY "Representante can create appeals"
  ON public.appeals FOR INSERT
  TO authenticated
  WITH CHECK (
    public.has_role(auth.uid(), 'representante') AND created_by = auth.uid()
  );

-- Create storage bucket for documents
INSERT INTO storage.buckets (id, name, public) VALUES ('process-documents', 'process-documents', false);

-- Storage policies
CREATE POLICY "Users can view documents for their processes"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'process-documents' AND
    EXISTS (
      SELECT 1 FROM public.evidence
      JOIN public.processes ON evidence.process_id = processes.id
      WHERE evidence.file_path = storage.objects.name
      AND (processes.creator_id = auth.uid() OR processes.judge_id = auth.uid() OR processes.representative_id = auth.uid())
    )
  );

CREATE POLICY "Criador and Representante can upload documents"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'process-documents' AND
    (public.has_role(auth.uid(), 'criador_processo') OR public.has_role(auth.uid(), 'representante'))
  );