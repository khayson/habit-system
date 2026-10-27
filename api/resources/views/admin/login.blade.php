@extends('admin.layout')
@section('title', 'Sign in')
@section('content')
<div style="min-height:100vh;display:grid;place-items:center;padding:16px">
  <div class="card" style="width:100%;max-width:420px;padding:32px">
    <div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">
      <svg width="40" height="40" viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="24" fill="#2F7B45"/><rect x="13" y="13" width="22" height="9" rx="4" fill="#E7F4E7" transform="rotate(-8 24 17)"/><rect x="12" y="18" width="24" height="9" rx="4" fill="#8BD799"/><rect x="11" y="23" width="26" height="14" rx="5" fill="#fff"/><path d="M17 30l4 4 9-9" stroke="#2F7B45" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
      <h1 style="margin:0;font-size:26px;font-weight:800">Habit admin</h1>
    </div>
    <p class="muted" style="margin-top:0">Sign in with your password and the code from your authenticator app.</p>
    <form method="post" action="/admin/login">
      @csrf
      <label for="email">Email</label>
      <input id="email" name="email" type="email" autocomplete="username" value="{{ old('email') }}" required>
      <label for="password">Password</label>
      <input id="password" name="password" type="password" autocomplete="current-password" required>
      <label for="code">6-digit code</label>
      <input id="code" name="code" inputmode="numeric" autocomplete="one-time-code" pattern="\d{6}" maxlength="6" required>
      <p style="margin-bottom:0"><button type="submit" style="width:100%">Sign in</button></p>
    </form>
  </div>
</div>
@endsection
