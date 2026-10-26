@extends('admin.layout')
@section('title', 'Sign in')
@section('content')
<div class="card" style="max-width:420px;margin:48px auto">
  <h1>Habit admin</h1>
  <form method="post" action="/admin/login">
    @csrf
    <label for="email">Email</label>
    <input id="email" name="email" type="email" autocomplete="username" value="{{ old('email') }}" required>
    <label for="password">Password</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required>
    <label for="code">Code from your authenticator app</label>
    <input id="code" name="code" inputmode="numeric" autocomplete="one-time-code" pattern="\d{6}" maxlength="6" required>
    <p><button type="submit">Sign in</button></p>
  </form>
</div>
@endsection
