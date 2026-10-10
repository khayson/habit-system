<?php

/*
 * Phase 3b (A20): writes contract-fixtures/profile/countries.json, the country list the server
 * validator and the app's picker share. Generated from CLDR (PHP intl), never written by hand.
 *
 *   php scripts/gen-countries.php
 *
 * Two-letter region codes only, minus CLDR's non-country codes. CLDR English names unedited,
 * sorted by name. ASSUMPTION(A3b-countries-xk): XK (Kosovo, a user-assigned code CLDR lists)
 * is kept.
 */

const DROPPED = ['AC', 'CP', 'CQ', 'DG', 'EA', 'EU', 'EZ', 'IC', 'TA', 'UN', 'XA', 'XB', 'ZZ', 'QO'];

$regions = ResourceBundle::create('en', 'ICUDATA-region');
$names = $regions === null ? null : $regions->get('Countries');
if ($names === null) {
    fwrite(STDERR, "error: CLDR region names are not available (intl)\n");
    exit(1);
}

$countries = [];
foreach ($names as $code => $name) {
    $code = (string) $code;
    if (preg_match('/^[A-Z]{2}$/', $code) && ! in_array($code, DROPPED, true)) {
        $countries[] = ['code' => $code, 'name' => (string) $name];
    }
}
$collator = new Collator('en');
usort($countries, fn (array $a, array $b) => $collator->compare($a['name'], $b['name']));

$target = dirname(__DIR__).'/contract-fixtures/profile/countries.json';
if (! is_dir(dirname($target))) {
    mkdir(dirname($target), 0777, true);
}
file_put_contents($target, json_encode($countries, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)."\n");

fwrite(STDOUT, sprintf("%d countries, first %s, last %s\n", count($countries), $countries[0]['code'], end($countries)['code']));
