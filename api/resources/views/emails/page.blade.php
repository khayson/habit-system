<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="color-scheme" content="light dark">
<title>@yield('title') · Habit System</title>
<style>
  @font-face { font-family: "Urbanist"; src: url("/admin-assets/urbanist.ttf") format("truetype"); font-weight: 100 900; font-display: swap; }
  :root { --bg:#F7F2EF; --surface:#FFFFFF; --ink:#1E1F22; --muted:#646464; --primary:#FF7616; --accent:#682E08; }
  @media (prefers-color-scheme: dark) { :root { --bg:#1A1411; --surface:#262019; --ink:#F7F2EF; --muted:#C2B8B0; --primary:#FF8A3D; --accent:#E8A070; } }
  body { margin:0; min-height:100vh; display:grid; place-items:center; padding:16px; box-sizing:border-box; background:var(--bg); color:var(--ink); font:17px/1.55 "Urbanist", system-ui, sans-serif; }
  main { max-width:480px; background:var(--surface); border-radius:24px; padding:32px; }
  h1 { font-size:26px; line-height:1.2; margin:0 0 12px; }
  p { margin:0 0 16px; }
  a { color:var(--accent); font-weight:700; }
  .button { display:inline-flex; align-items:center; min-height:44px; padding:10px 22px; border-radius:999px; background:var(--primary); color:#1E1F22; text-decoration:none; }
</style>
</head>
<body><main>@yield('content')</main></body>
</html>
