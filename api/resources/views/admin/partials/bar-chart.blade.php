{{--
  A58: one measure as 30 thin bars (rolling 24-hour buckets, oldest at the left). One series,
  so no legend: the title names it. Each bar carries its own tooltip (an SVG title, no script),
  and the table under it gives every value.
  $title, $values (list<int>), $ends (list<string> UTC), $noun (e.g. "sign-ups"), $total (string)
--}}
@php
  $max = max(1, max($values));
  // A round axis top: 1, 2, 5 × 10^n at or above the largest value.
  $top = 1;
  foreach ([1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000] as $step) {
      if ($step >= $max) { $top = $step; break; }
      $top = $step;
  }
  // Drawn near the size it shows at (a third of the page), so its labels keep their real size.
  $w = 340; $h = 160; $left = 28; $bottom = 22; $plotH = $h - $bottom - 8; $plotW = $w - $left;
  $n = count($values); $slot = $plotW / $n; $barW = max(2, $slot - 2);
  $y = fn ($v) => 8 + $plotH - ($v / $top) * $plotH;
  $label = fn (int $i) => \Carbon\CarbonImmutable::parse($ends[$i])->format('j M');
@endphp
<figure class="card chart" style="margin:0">
  <div class="head">
    <h3>{{ $title }}</h3>
    <span class="total"><b>{{ $total }}</b> in 30 days</span>
  </div>
  <svg viewBox="0 0 {{ $w }} {{ $h }}" role="img" aria-label="{{ $title }}, last 30 days: {{ $total }} in all, at most {{ $max }} in one day.">
    @foreach ([0, 0.5, 1] as $f)
      <line class="gridline" x1="{{ $left }}" x2="{{ $w }}" y1="{{ $y($top * $f) }}" y2="{{ $y($top * $f) }}"/>
      <text x="{{ $left - 6 }}" y="{{ $y($top * $f) + 4 }}" text-anchor="end">{{ $top * $f == (int) ($top * $f) ? (int) ($top * $f) : $top * $f }}</text>
    @endforeach
    @foreach ($values as $i => $v)
      @php $barH = $v === 0 ? 0 : max(3, ($v / $top) * $plotH); @endphp
      <g>
        <title>{{ number_format($v) }} {{ $noun }} in the 24 hours to {{ \Carbon\CarbonImmutable::parse($ends[$i])->format('j M, H:i') }} UTC</title>
        {{-- An invisible full-height hit area, so a thin bar is easy to point at. --}}
        <rect x="{{ $left + $i * $slot }}" y="8" width="{{ $slot }}" height="{{ $plotH }}" fill="transparent"/>
        @if ($barH > 0)
          <path class="bar" d="M{{ $left + $i * $slot + 1 }},{{ 8 + $plotH }} v-{{ $barH - 2 }} q0,-2 2,-2 h{{ $barW - 4 }} q2,0 2,2 v{{ $barH - 2 }} z"/>
        @endif
      </g>
    @endforeach
    @foreach ([0, intdiv($n, 2), $n - 1] as $i)
      <text x="{{ $left + $i * $slot + $slot / 2 }}" y="{{ $h - 6 }}" text-anchor="{{ $i === 0 ? 'start' : ($i === $n - 1 ? 'end' : 'middle') }}">{{ $label($i) }}</text>
    @endforeach
  </svg>
  <details>
    <summary>Show as a table</summary>
    <table>
      <thead><tr><th scope="col">24 hours to (UTC)</th><th scope="col" class="num">{{ ucfirst($noun) }}</th></tr></thead>
      <tbody>
        @foreach (array_reverse(array_keys($values)) as $i)
          <tr><td class="mono">{{ \Carbon\CarbonImmutable::parse($ends[$i])->format('j M, H:i') }}</td><td class="num">{{ number_format($values[$i]) }}</td></tr>
        @endforeach
      </tbody>
    </table>
  </details>
</figure>
