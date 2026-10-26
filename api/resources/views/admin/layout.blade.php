<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>@yield('title') · Habit admin</title>
<style>
  :root { --bg:#F7F2EF; --surface:#FFFFFF; --ink:#1E1F22; --muted:#646464; --border:#ECE4DE;
          --primary:#FF7616; --accent:#682E08; --selected:#292C31; --warn-bg:#FFE8C2; --warn:#87470A;
          --err-bg:#FCE1DE; --err:#A3271B; --ok-bg:#E5EFBA; --ok:#475610; }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  header { display:flex; flex-wrap:wrap; gap:8px 20px; align-items:center; padding:16px 24px; background:var(--surface); border-bottom:1px solid var(--border); }
  header strong { margin-right:auto; }
  header a { color:var(--accent); text-decoration:none; font-weight:600; padding:10px 4px; }
  header a[aria-current="page"] { text-decoration:underline; text-underline-offset:6px; }
  main { max-width:1040px; margin:0 auto; padding:24px 16px 48px; }
  h1 { font-size:28px; margin:8px 0 16px; }
  h2 { font-size:20px; margin:28px 0 12px; }
  .card { background:var(--surface); border-radius:20px; padding:20px; margin-bottom:16px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:12px; }
  .stat { background:var(--surface); border-radius:16px; padding:16px; }
  .stat b { display:block; font-size:24px; }
  .stat span { color:var(--muted); font-size:14px; }
  table { width:100%; border-collapse:collapse; background:var(--surface); border-radius:16px; overflow:hidden; }
  th, td { text-align:left; padding:12px; border-bottom:1px solid var(--border); vertical-align:top; }
  th { font-size:14px; color:var(--muted); font-weight:600; }
  a { color:var(--accent); }
  .muted { color:var(--muted); font-size:14px; }
  .pill { display:inline-block; padding:2px 10px; border-radius:999px; font-size:14px; }
  .pill.active { background:var(--ok-bg); color:var(--ok); }
  .pill.suspended { background:var(--warn-bg); color:var(--warn); }
  .pill.deletion { background:var(--err-bg); color:var(--err); }
  label { display:block; font-weight:600; margin:12px 0 6px; }
  input, textarea { width:100%; min-height:44px; padding:10px 14px; border:1px solid var(--border); border-radius:14px; font:inherit; background:var(--surface); color:var(--ink); }
  textarea { min-height:96px; }
  button { min-height:44px; padding:10px 20px; border:0; border-radius:999px; font:inherit; font-weight:600; cursor:pointer; background:var(--primary); color:var(--ink); }
  button.secondary { background:var(--selected); color:#fff; }
  button.danger { background:var(--err); color:#fff; }
  form.inline { display:inline-block; margin:4px 8px 4px 0; }
  .flash { background:var(--ok-bg); color:var(--ok); padding:12px 16px; border-radius:14px; margin-bottom:16px; }
  .error { background:var(--err-bg); color:var(--err); padding:12px 16px; border-radius:14px; margin-bottom:16px; }
  :focus-visible { outline:3px solid var(--selected); outline-offset:2px; }
</style>
</head>
<body>
@hasSection('nav')
<header>
  <strong>Habit admin</strong>
  <a href="/admin" @if(request()->is('admin')) aria-current="page" @endif>System</a>
  <a href="/admin/accounts" @if(request()->is('admin/accounts*')) aria-current="page" @endif>Accounts</a>
  <a href="/admin/notices" @if(request()->is('admin/notices*')) aria-current="page" @endif>Notices</a>
  <form method="post" action="/admin/logout" class="inline">@csrf<button class="secondary" type="submit">Sign out</button></form>
</header>
@endif
<main>
  @if (session('status'))<div class="flash" role="status">{{ session('status') }}</div>@endif
  @if ($errors->any())<div class="error" role="alert">{{ $errors->first() }}</div>@endif
  @yield('content')
</main>
</body>
</html>
