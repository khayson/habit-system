{{--
  A58: a headline number on a pastel tile, with this week against last week in words (never
  colour alone). $label, $value, $tile (peach|lime|pink), $icon (svg path), optional $now/$before
  and $what (what the week counts, when it differs from the headline)
--}}
<div class="kpi">
  <div class="label">
    <span class="tile" style="background:var(--{{ $tile }})"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="{{ $icon }}"/></svg></span>
    {{ $label }}
  </div>
  <div class="value mono">{{ number_format($value) }}</div>
  @isset($now)
    @php
      $diff = $now - $before;
      $words = $before === 0
          ? ($now === 0 ? 'none either week' : 'new this week')
          : (($diff >= 0 ? '+' : '−').round(abs($diff) / $before * 100).'% on last week');
    @endphp
    <div class="delta"><b>{{ number_format($now) }}</b> {{ $what ?? '' }} this week · {{ $words }} ({{ number_format($before) }})</div>
  @endisset
</div>
