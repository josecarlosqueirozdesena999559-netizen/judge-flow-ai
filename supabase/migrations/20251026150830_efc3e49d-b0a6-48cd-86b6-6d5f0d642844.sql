-- Fix search_path for security
CREATE OR REPLACE FUNCTION public.generate_process_number()
RETURNS TEXT
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = public
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

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;