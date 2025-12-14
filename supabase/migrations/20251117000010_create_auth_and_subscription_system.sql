-- Migration: Authentication and Subscription System
-- Created: 2025-11-17
-- Description: Complete authentication via WhatsApp and subscription management system

-- ===========================================
-- 1. WILAYAT (STATES) TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS public.wilayat (
    id TEXT PRIMARY KEY,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert all 15 Mauritanian wilayat (states)
INSERT INTO public.wilayat (id, name_ar, name_fr, display_order) VALUES
('hodh-chargui', 'الحوض الشرقي', 'Hodh Ech Chargui', 1),
('hodh-gharbi', 'الحوض الغربي', 'Hodh El Gharbi', 2),
('assaba', 'العصابة', 'Assaba', 3),
('gorgol', 'كوركول', 'Gorgol', 4),
('brakna', 'البراكنة', 'Brakna', 5),
('trarza', 'الترارزة', 'Trarza', 6),
('adrar', 'أدرار', 'Adrar', 7),
('dakhlet-nouadhibou', 'داخلت نواذيبو', 'Dakhlet Nouadhibou', 8),
('tagant', 'تكانت', 'Tagant', 9),
('guidimaka', 'كيديماغا', 'Guidimaka', 10),
('tiris-zemmour', 'تيرس زمور', 'Tiris Zemmour', 11),
('inchiri', 'إنشيري', 'Inchiri', 12),
('nouakchott-nord', 'نواكشوط الشمالية', 'Nouakchott Nord', 13),
('nouakchott-ouest', 'نواكشوط الغربية', 'Nouakchott Ouest', 14),
('nouakchott-sud', 'نواكشوط الجنوبية', 'Nouakchott Sud', 15);

-- Enable RLS
ALTER TABLE public.wilayat ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wilayat (read-only for all users)
CREATE POLICY "Wilayat are viewable by everyone"
    ON public.wilayat FOR SELECT
    USING (is_active = true);

CREATE POLICY "Only admins can insert wilayat"
    ON public.wilayat FOR INSERT
    WITH CHECK (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Only admins can update wilayat"
    ON public.wilayat FOR UPDATE
    USING (auth.jwt() ->> 'role' = 'admin');

-- ===========================================
-- 2. UPDATE PROFILES TABLE
-- ===========================================
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS phone_number TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS wilaya_id TEXT REFERENCES public.wilayat(id),
ADD COLUMN IF NOT EXISTS is_phone_verified BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ;

-- Create index on phone_number for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number ON public.profiles(phone_number);

-- ===========================================
-- 3. SUBSCRIPTION PLANS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grade_id TEXT NOT NULL REFERENCES public.grades(id) ON DELETE CASCADE,
    specialization_id TEXT REFERENCES public.specializations(id) ON DELETE CASCADE,
    duration_type TEXT NOT NULL CHECK (duration_type IN ('monthly', 'annual')),
    price_ouguiya DECIMAL(10, 2) NOT NULL DEFAULT 0,
    name_ar TEXT NOT NULL,
    name_fr TEXT,
    description_ar TEXT,
    description_fr TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure unique combination
    UNIQUE(grade_id, specialization_id, duration_type)
);

-- Enable RLS
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscription_plans
CREATE POLICY "Subscription plans are viewable by everyone"
    ON public.subscription_plans FOR SELECT
    USING (is_active = true);

CREATE POLICY "Only admins can manage subscription plans"
    ON public.subscription_plans FOR ALL
    USING (auth.jwt() ->> 'role' = 'admin');

-- ===========================================
-- 4. SUBSCRIPTIONS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled')),
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    payment_verified_by UUID REFERENCES auth.users(id),
    payment_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscriptions
CREATE POLICY "Users can view their own subscriptions"
    ON public.subscriptions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all subscriptions"
    ON public.subscriptions FOR SELECT
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Admins can manage subscriptions"
    ON public.subscriptions FOR ALL
    USING (auth.jwt() ->> 'role' = 'admin');

-- ===========================================
-- 5. PAYMENT PROOFS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS public.payment_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_notes TEXT,
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.payment_proofs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for payment_proofs
CREATE POLICY "Users can view their own payment proofs"
    ON public.payment_proofs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create payment proofs"
    ON public.payment_proofs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all payment proofs"
    ON public.payment_proofs FOR SELECT
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Admins can update payment proofs"
    ON public.payment_proofs FOR UPDATE
    USING (auth.jwt() ->> 'role' = 'admin');

-- ===========================================
-- 6. OTP VERIFICATION TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS public.otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for otp_verifications (no public access, only backend functions)
CREATE POLICY "Only system can manage OTP verifications"
    ON public.otp_verifications FOR ALL
    USING (false); -- No direct access, only via RPC functions

-- ===========================================
-- 7. INDEXES FOR PERFORMANCE
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_end_date ON public.subscriptions(end_date);
CREATE INDEX IF NOT EXISTS idx_payment_proofs_status ON public.payment_proofs(status);
CREATE INDEX IF NOT EXISTS idx_payment_proofs_user_id ON public.payment_proofs(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_phone_number ON public.otp_verifications(phone_number);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON public.otp_verifications(expires_at);

-- ===========================================
-- 8. FUNCTIONS
-- ===========================================

-- Function to convert phone number to email format for Supabase Auth
CREATE OR REPLACE FUNCTION public.phone_to_email(phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    -- Convert +222XXXXXXXX to +222xxxxxxxx@telebac.mr
    RETURN LOWER(REPLACE(phone, '+', '')) || '@telebac.mr';
END;
$$;

-- Function to check if user has active subscription
CREATE OR REPLACE FUNCTION public.has_active_subscription(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    active_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO active_count
    FROM public.subscriptions
    WHERE user_id = user_uuid
    AND status = 'active'
    AND end_date > NOW();

    RETURN active_count > 0;
END;
$$;

-- Function to get user's active subscription
CREATE OR REPLACE FUNCTION public.get_active_subscription(user_uuid UUID)
RETURNS TABLE (
    id UUID,
    plan_id UUID,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    plan_name_ar TEXT,
    grade_name TEXT,
    specialization_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.plan_id,
        s.start_date,
        s.end_date,
        sp.name_ar,
        g.name_ar as grade_name,
        COALESCE(spec.name_ar, 'عام') as specialization_name
    FROM public.subscriptions s
    JOIN public.subscription_plans sp ON sp.id = s.plan_id
    JOIN public.grades g ON g.id = sp.grade_id
    LEFT JOIN public.specializations spec ON spec.id = sp.specialization_id
    WHERE s.user_id = user_uuid
    AND s.status = 'active'
    AND s.end_date > NOW()
    ORDER BY s.end_date DESC
    LIMIT 1;
END;
$$;

-- ===========================================
-- 9. SEED DEFAULT SUBSCRIPTION PLANS
-- ===========================================

-- For 4th Preparatory (no specialization)
INSERT INTO public.subscription_plans (grade_id, specialization_id, duration_type, price_ouguiya, name_ar, name_fr)
VALUES
('prep-4', NULL, 'monthly', 5000, 'اشتراك شهري - الرابعة إعدادي', 'Abonnement mensuel - 4ème année préparatoire'),
('prep-4', NULL, 'annual', 50000, 'اشتراك سنوي - الرابعة إعدادي', 'Abonnement annuel - 4ème année préparatoire');

-- For 2nd Secondary with specializations
INSERT INTO public.subscription_plans (grade_id, specialization_id, duration_type, price_ouguiya, name_ar, name_fr)
SELECT
    'sec-2',
    s.id,
    'monthly',
    6000,
    'اشتراك شهري - ' || s.name_ar,
    'Abonnement mensuel - ' || s.name_fr
FROM public.specializations s
WHERE s.grade_id = 'sec-2' AND s.is_active = true;

INSERT INTO public.subscription_plans (grade_id, specialization_id, duration_type, price_ouguiya, name_ar, name_fr)
SELECT
    'sec-2',
    s.id,
    'annual',
    60000,
    'اشتراك سنوي - ' || s.name_ar,
    'Abonnement annuel - ' || s.name_fr
FROM public.specializations s
WHERE s.grade_id = 'sec-2' AND s.is_active = true;

-- For 3rd Secondary (Baccalaureate) with specializations
INSERT INTO public.subscription_plans (grade_id, specialization_id, duration_type, price_ouguiya, name_ar, name_fr)
SELECT
    'sec-3',
    s.id,
    'monthly',
    7000,
    'اشتراك شهري - ' || s.name_ar,
    'Abonnement mensuel - ' || s.name_fr
FROM public.specializations s
WHERE s.grade_id = 'sec-3' AND s.is_active = true;

INSERT INTO public.subscription_plans (grade_id, specialization_id, duration_type, price_ouguiya, name_ar, name_fr)
SELECT
    'sec-3',
    s.id,
    'annual',
    70000,
    'اشتراك سنوي - ' || s.name_ar,
    'Abonnement annuel - ' || s.name_fr
FROM public.specializations s
WHERE s.grade_id = 'sec-3' AND s.is_active = true;

-- ===========================================
-- 10. TRIGGERS
-- ===========================================

-- Update updated_at timestamp on subscription_plans
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_subscription_plans_updated_at
    BEFORE UPDATE ON public.subscription_plans
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_payment_proofs_updated_at
    BEFORE UPDATE ON public.payment_proofs
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_wilayat_updated_at
    BEFORE UPDATE ON public.wilayat
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ===========================================
-- MIGRATION COMPLETE
-- ===========================================
