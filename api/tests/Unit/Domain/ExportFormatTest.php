<?php

use App\Domain\Export\CanonicalJson;
use App\Domain\Export\CsvWriter;
use App\Domain\Export\ManifestCheck;
use App\Domain\Export\ManifestSigner;

/*
 * A16 / A48: contract-fixtures/exports/export_manifest.json (its canonical JSON and HMAC were
 * computed outside PHP) and export_csv.json.
 */

function exportFixture(string $name): array
{
    return json_decode((string) file_get_contents(dirname(__DIR__, 4)."/contract-fixtures/exports/{$name}.json"), true, flags: JSON_THROW_ON_ERROR);
}

it('writes the canonical JSON and signature of the fixture manifest', function () {
    $f = exportFixture('export_manifest');
    $signer = new ManifestSigner($f['keys'], 'test-2026');
    $unsigned = $f['manifest'];
    unset($unsigned['kid']);

    $signed = $signer->sign($unsigned);

    $withoutSignature = $signed;
    unset($withoutSignature['signature']);
    expect(CanonicalJson::encode($withoutSignature))->toBe($f['canonical'])
        ->and($signed['signature'])->toBe($f['signature'])
        ->and($signer->verify($signed))->toBe(ManifestCheck::Valid);
});

it('refuses a tampered manifest or an unknown kid', function (array $case) {
    $f = exportFixture('export_manifest');
    $manifest = [...$f['manifest'], 'signature' => $f['signature'], ...$case['set']];

    expect((new ManifestSigner($f['keys'], 'test-2026'))->verify($manifest)->value)->toBe($case['reason']);
})->with(fn () => array_map(fn ($c) => [$c], exportFixture('export_manifest')['tampered']));

it('parses signing keys from config', function () {
    expect(ManifestSigner::parseKeys(' a:one , b:two:with:colons,broken, :x '))->toBe(['a' => 'one', 'b' => 'two:with:colons']);
});

it('neutralises and quotes every fixture cell', function (array $cell) {
    expect(CsvWriter::userCell($cell['in']))->toBe($cell['out']);
})->with(fn () => array_map(fn ($c) => [$c], exportFixture('export_csv')['cells']));

it('writes the header and a row as the fixture says', function () {
    $f = exportFixture('export_csv');

    expect(CsvWriter::header())->toBe(implode(',', $f['header'])."\n")
        ->and(CsvWriter::row($f['row']['in']))->toBe($f['row']['out']."\n");
});
