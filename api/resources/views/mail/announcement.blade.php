<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>{{ $subjectLine }}</title>
</head>
<body style="margin:0;padding:24px 12px;background:#F7F2EF;font-family:'Segoe UI',Roboto,Arial,sans-serif;color:#1E1F22;">
<div style="max-width:560px;margin:0 auto;">
  <p style="margin:0 0 14px;font-size:15px;font-weight:700;color:#1E1F22;">
    <span style="display:inline-block;width:22px;height:22px;border-radius:50%;background:#2F7B45;vertical-align:-5px;margin-right:8px;"></span>Habit System
  </p>
  <div style="background:#FFFFFF;border-radius:20px;padding:28px;">
    @foreach ($paragraphs as $p)
      <p style="margin:0 0 16px;font-size:16px;line-height:1.55;">{!! nl2br(e($p)) !!}</p>
    @endforeach
  </div>
  <p style="margin:16px 4px 0;font-size:13px;line-height:1.5;color:#646464;">
    You are getting this because you have a Habit System account. It is a service announcement, not marketing.
    @if ($stopUrl)
      <a href="{{ $stopUrl }}" style="color:#682E08;">Stop these emails</a>. Password reset codes still arrive.
    @else
      (Recipients see a "Stop these emails" link here.)
    @endif
  </p>
</div>
</body>
</html>
