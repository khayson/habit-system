@php
  $nav = [
    ['/admin', 'Overview', 'admin', 'M3 12h4l3-8 4 16 3-8h4'],
    ['/admin/health', 'Health & jobs', 'admin/health*', 'M12 21s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.5-7 10-7 10z'],
    ['/admin/accounts', 'Accounts', 'admin/accounts*', 'M16 19v-1a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v1M10 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM20 19v-1a4 4 0 0 0-3-3.9M15 4.1a3 3 0 0 1 0 5.8'],
    ['/admin/notices', 'Notices', 'admin/notices*', 'M4 5h16v11H8l-4 4V5z'],
    ['/admin/activity', 'Activity log', 'admin/activity*', 'M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01'],
  ];
@endphp
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="color-scheme" content="light dark">
<title>@yield('title') · Habit admin</title>
<style>
  @font-face { font-family: "Urbanist"; src: url("/admin-assets/urbanist.ttf") format("truetype"); font-weight: 100 900; font-display: swap; }
  :root {
    --bg:#F7F2EF; --canvas:#EFE8E3; --surface:#FFFFFF; --ink:#1E1F22; --muted:#646464; --border:#ECE4DE;
    --primary:#FF7616; --on-primary:#1E1F22; --accent:#682E08; --selected:#292C31; --on-selected:#FFFFFF;
    --chart:#99470F; --grid:#E4DDD5;
    --ok-bg:#E5EFBA; --ok:#475610; --warn-bg:#FFE8C2; --warn:#87470A; --err-bg:#FCE1DE; --err:#A3271B;
    --peach:#FFD5BC; --lime:#E5EFBA; --pink:#FFDEF8;
    --shadow: 0 1px 2px rgba(30,31,34,.04), 0 8px 24px rgba(30,31,34,.05);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg:#1A1411; --canvas:#120D0A; --surface:#262019; --ink:#F7F2EF; --muted:#C2B8B0; --border:#3E342D;
      --primary:#FF8A3D; --on-primary:#1E1F22; --accent:#E8A070; --selected:#F7F2EF; --on-selected:#1E1F22;
      --chart:#D27A3A; --grid:#3A302A;
      --ok-bg:#34401A; --ok:#E5EFBA; --warn-bg:#4A3416; --warn:#FFD9A0; --err-bg:#4D2320; --err:#FFB4AA;
      --peach:#4A2E1E; --lime:#343F1C; --pink:#47253F;
      --shadow: none;
    }
  }
  * { box-sizing: border-box; }
  html, body { margin:0; }
  body { background:var(--bg); color:var(--ink); font:16px/1.5 "Urbanist", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  a { color:var(--accent); }
  :focus-visible { outline:3px solid var(--selected); outline-offset:2px; border-radius:8px; }
  .skip { position:absolute; left:-999px; top:8px; background:var(--surface); padding:8px 12px; border-radius:10px; z-index:10; }
  .skip:focus { left:8px; }

  /* Shell: sidebar + sticky top bar. */
  .shell { display:grid; grid-template-columns: 248px minmax(0, 1fr); min-height:100vh; }
  .shell > div { min-width:0; }
  .sidebar { position:sticky; top:0; height:100vh; background:var(--surface); border-right:1px solid var(--border); padding:20px 14px; display:flex; flex-direction:column; gap:6px; }
  .brand { display:flex; align-items:center; gap:10px; padding:4px 10px 18px; font-weight:800; font-size:18px; color:var(--ink); text-decoration:none; }
  .brand svg { flex:none; }
  .navlink { display:flex; align-items:center; gap:12px; min-height:44px; padding:10px 12px; border-radius:14px; color:var(--ink); text-decoration:none; font-weight:600; }
  .navlink svg { width:20px; height:20px; flex:none; stroke:currentColor; fill:none; stroke-width:1.8; stroke-linecap:round; stroke-linejoin:round; }
  .navlink:hover { background:var(--bg); }
  .navlink[aria-current="page"] { background:var(--selected); color:var(--on-selected); }
  .sidebar .spacer { flex:1; }
  .sidebar .who { font-size:13px; color:var(--muted); padding:8px 12px; word-break:break-all; }

  .topbar { position:sticky; top:0; z-index:5; display:flex; align-items:center; gap:16px; padding:14px 28px; background:color-mix(in srgb, var(--bg) 88%, transparent); backdrop-filter:blur(8px); border-bottom:1px solid var(--border); }
  .topbar h1 { font-size:22px; margin:0; font-weight:800; }
  .topbar .grow { flex:1; }
  .tabs { display:none; }
  main { padding:24px 28px 56px; max-width:1180px; }

  @media (max-width: 860px) {
    .shell { grid-template-columns: minmax(0, 1fr); }
    .sidebar { display:none; }
    .topbar { flex-wrap:wrap; padding:12px 16px; }
    .tabs { display:flex; gap:6px; overflow-x:auto; width:100%; padding-bottom:2px; }
    .tabs a { flex:none; min-height:44px; display:flex; align-items:center; padding:8px 14px; border-radius:999px; background:var(--surface); color:var(--ink); text-decoration:none; font-weight:600; font-size:15px; }
    .tabs a[aria-current="page"] { background:var(--selected); color:var(--on-selected); }
    main { padding:16px 16px 48px; }
  }

  /* Pieces. */
  h2 { font-size:19px; margin:32px 0 12px; font-weight:800; }
  .sub { color:var(--muted); font-size:14px; margin:-8px 0 16px; }
  .card { background:var(--surface); border-radius:20px; padding:20px; box-shadow:var(--shadow); }
  .grid { display:grid; gap:14px; }
  .grid.k4 { grid-template-columns:repeat(auto-fit, minmax(min(210px, 100%), 1fr)); }
  .grid.c3 { grid-template-columns:repeat(auto-fit, minmax(min(300px, 100%), 1fr)); }
  .grid.c2 { grid-template-columns:repeat(auto-fit, minmax(min(340px, 100%), 1fr)); }
  .kpi { background:var(--surface); border-radius:20px; padding:18px 20px; box-shadow:var(--shadow); display:flex; flex-direction:column; gap:6px; }
  .kpi .label { display:flex; align-items:center; gap:10px; color:var(--muted); font-size:14px; font-weight:600; }
  .kpi .tile { width:36px; height:36px; border-radius:12px; display:grid; place-items:center; }
  .kpi .tile svg { width:18px; height:18px; stroke:var(--ink); fill:none; stroke-width:1.8; stroke-linecap:round; stroke-linejoin:round; }
  .kpi .value { font-size:32px; font-weight:800; line-height:1.1; }
  .delta { font-size:13px; font-weight:600; color:var(--muted); }
  .delta b { font-weight:700; color:var(--ink); }
  table { width:100%; border-collapse:collapse; }
  .table { background:var(--surface); border-radius:20px; box-shadow:var(--shadow); overflow-x:auto; }
  th, td { text-align:left; padding:12px 16px; border-bottom:1px solid var(--border); vertical-align:middle; }
  tr:last-child td { border-bottom:0; }
  th { font-size:13px; color:var(--muted); font-weight:700; white-space:nowrap; }
  td.num, th.num { text-align:right; font-variant-numeric:tabular-nums; }
  .muted { color:var(--muted); font-size:14px; }
  .mono { font-variant-numeric:tabular-nums; }
  .pill { display:inline-flex; align-items:center; gap:6px; padding:3px 10px; border-radius:999px; font-size:13px; font-weight:700; white-space:nowrap; }
  .pill::before { content:""; width:6px; height:6px; border-radius:50%; background:currentColor; }
  .pill.active, .pill.ok { background:var(--ok-bg); color:var(--ok); }
  .pill.suspended, .pill.warn { background:var(--warn-bg); color:var(--warn); }
  .pill.deletion, .pill.err { background:var(--err-bg); color:var(--err); }
  label { display:block; font-weight:700; font-size:14px; margin:12px 0 6px; }
  input, textarea, select { width:100%; min-height:44px; padding:10px 14px; border:1px solid var(--border); border-radius:14px; font:inherit; background:var(--surface); color:var(--ink); }
  textarea { min-height:96px; resize:vertical; }
  button, .button { white-space:nowrap; display:inline-flex; align-items:center; justify-content:center; gap:8px; min-height:44px; padding:10px 20px; border:0; border-radius:999px; font:inherit; font-weight:700; cursor:pointer; background:var(--primary); color:var(--on-primary); text-decoration:none; }
  button.secondary, .button.secondary { background:var(--selected); color:var(--on-selected); }
  button.ghost { background:transparent; color:var(--accent); padding:10px 12px; }
  button.danger { background:var(--err); color:#fff; }
  form.inline { display:inline-flex; margin:0; }
  .actions { display:flex; flex-wrap:wrap; gap:10px; align-items:center; }
  .flash { background:var(--ok-bg); color:var(--ok); padding:12px 16px; border-radius:14px; margin-bottom:16px; font-weight:600; }
  .error { background:var(--err-bg); color:var(--err); padding:12px 16px; border-radius:14px; margin-bottom:16px; font-weight:600; }
  .filters { display:flex; flex-wrap:wrap; gap:10px; align-items:end; margin-bottom:14px; }
  .filters > div { min-width:160px; flex:1; }
  .filters label { margin-top:0; }
  .chips { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:14px; }
  .chips a { min-height:40px; display:inline-flex; align-items:center; gap:6px; padding:6px 14px; border-radius:999px; background:var(--surface); color:var(--ink); text-decoration:none; font-weight:600; font-size:14px; box-shadow:var(--shadow); }
  .chips a[aria-current="true"] { background:var(--selected); color:var(--on-selected); }
  .chips .count { opacity:.75; font-variant-numeric:tabular-nums; }
  .pager { display:flex; gap:14px; margin-top:14px; }
  .meter { height:10px; border-radius:999px; background:var(--grid); overflow:hidden; }
  .meter span { display:block; height:100%; background:var(--chart); border-radius:999px; }
  details summary { cursor:pointer; color:var(--accent); font-weight:600; font-size:14px; min-height:32px; display:flex; align-items:center; }
  .chart svg { width:100%; height:auto; display:block; }
  .chart .bar { fill:var(--chart); }
  .chart .bar:hover { opacity:.8; }
  .chart .gridline { stroke:var(--grid); stroke-width:1; }
  .chart text { fill:var(--muted); font:12px "Urbanist", system-ui, sans-serif; }
  .chart .head { display:flex; justify-content:space-between; align-items:baseline; gap:12px; }
  .chart .head h3 { margin:0; font-size:16px; font-weight:800; }
  .chart .head .total { font-size:14px; color:var(--muted); }
  .chart .head .total b { color:var(--ink); font-size:18px; }
  .empty { text-align:center; padding:28px 16px; color:var(--muted); }
</style>
</head>
<body>
<a class="skip" href="#content">Skip to content</a>
@hasSection('nav')
<div class="shell">
  <aside class="sidebar" aria-label="Admin sections">
    <a class="brand" href="/admin">
      <svg width="30" height="30" viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="24" fill="#2F7B45"/><rect x="13" y="13" width="22" height="9" rx="4" fill="#E7F4E7" transform="rotate(-8 24 17)"/><rect x="12" y="18" width="24" height="9" rx="4" fill="#8BD799"/><rect x="11" y="23" width="26" height="14" rx="5" fill="#fff"/><path d="M17 30l4 4 9-9" stroke="#2F7B45" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
      Habit admin
    </a>
    @foreach ($nav as [$href, $label, $pattern, $path])
      <a class="navlink" href="{{ $href }}" @if(request()->is($pattern)) aria-current="page" @endif>
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="{{ $path }}"/></svg>{{ $label }}
      </a>
    @endforeach
    <div class="spacer"></div>
    <div class="who">Signed in as {{ config('admin.email') }}</div>
    <form method="post" action="/admin/logout">@csrf<button class="secondary" type="submit" style="width:100%">Sign out</button></form>
  </aside>
  <div>
    <header class="topbar">
      <h1>@yield('title')</h1>
      <div class="grow"></div>
      @yield('top-actions')
      <nav class="tabs" aria-label="Admin sections">
        @foreach ($nav as [$href, $label, $pattern])
          <a href="{{ $href }}" @if(request()->is($pattern)) aria-current="page" @endif>{{ $label }}</a>
        @endforeach
        <form method="post" action="/admin/logout" class="inline">@csrf<button class="secondary" type="submit">Sign out</button></form>
      </nav>
    </header>
    <main id="content">
      @if (session('status'))<div class="flash" role="status">{{ session('status') }}</div>@endif
      @if ($errors->any())<div class="error" role="alert">{{ $errors->first() }}</div>@endif
      @yield('content')
    </main>
  </div>
</div>
@else
<main id="content">
  @if ($errors->any())<div class="error" role="alert">{{ $errors->first() }}</div>@endif
  @yield('content')
</main>
@endif
</body>
</html>
