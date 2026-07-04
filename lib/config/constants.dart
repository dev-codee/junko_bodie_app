/// App-wide constants — API URLs, Supabase keys, etc.
///
/// The Flutter app calls the existing Next.js backend deployed on Vercel.
/// No backend changes are needed.
library;

const String apiBaseUrl = 'https://junkobodieroulette.com';

// Supabase — same project as the web app
const String supabaseUrl = 'https://yxwtfbnajhjzhkusfiyg.supabase.co';
const String supabaseAnonKey =
    'sb_publishable_WFdIem-RkS85RS0DjLoOOg_w9nayrlU';

// Default starting balance for new players
const double defaultBalance = 1000.0;

// Subscription plans
const String monthlyPrice = '\$4.99';
const String annualPrice = '\$54.99';
