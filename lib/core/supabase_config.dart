/// Supabase project credentials.
/// The anon key is safe to embed — Row Level Security policies protect data.
class SupabaseConfig {
  static const String url = 'https://nvgjkqdgylngwutwhvdd.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52Z2prcWRneWxuZ3d1dHdodmRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNTk5MDQsImV4cCI6MjA5NTgzNTkwNH0.I6XbE_UfFV341-KTc-XizGElbJfpllloe-racWdlgmw';

  /// Secret code required to create an admin account.
  /// Anyone with this code can grant themselves admin at signup.
  /// In production, this should be replaced with an invite-token system.
  static const String adminSecret = 'W2G-ADMIN-2026';
}
