use strict;
use warnings;
use Test::More 0.88;

use lib 't/lib';

use autodie;
use Test::DZil;

my $with_version = '
package DZT::WVer;
our $DIST = \'DZT-Blort\';
1;
';

my $two_packages = '
package DZT::TP1;

package DZT::TP2;

1;
';

my $repeated_packages = '
package DZT::R1;

package DZT::R2;

package DZT::R1;

1;
';

my $monkey_patched = '
package DZT::TP1;

package
 DZT::TP2;

1;
';

my $script = '
#!/usr/bin/perl

print "hello world\n";
';

my $script_pkg = '
#!/usr/bin/perl

package DZT::Script;
';

my $tzil = Builder->from_config(
  { dist_root => 'corpus/dist/DZT' },
  {
    add_files => {
      'source/lib/DZT/TP1.pm'    => $two_packages,
      'source/lib/DZT/WVer.pm'   => $with_version,
      'source/lib/DZT/R1.pm'     => $repeated_packages,
      'source/lib/DZT/Monkey.pm' => $monkey_patched,
      'source/bin/script_pkg.pl' => $script_pkg,
      'source/bin/script_ver.pl' => $script_pkg . "our \$DIST = 'DZT-Blort';\n",
      'source/bin/script.pl'     => $script,
      'source/dist.ini' => simple_ini('GatherDir', 'PkgDist', 'ExecDir'),
    },
  },
);

$tzil->build;

my $dzt_sample = $tzil->slurp_file('build/lib/DZT/Sample.pm');
like(
  $dzt_sample,
  qr{^\s*\$\QDZT::Sample::DIST = 'DZT-Sample';\E\s*$}m,
  "added version to DZT::Sample",
);

my $dzt_tp1 = $tzil->slurp_file('build/lib/DZT/TP1.pm');
like(
  $dzt_tp1,
  qr{^\s*\$\QDZT::TP1::DIST = 'DZT-Sample';\E\s*$}m,
  "added version to DZT::TP1",
);

like(
  $dzt_tp1,
  qr{^\s*\$\QDZT::TP2::DIST = 'DZT-Sample';\E\s*$}m,
  "added version to DZT::TP2",
);

my $dzt_wver = $tzil->slurp_file('build/lib/DZT/WVer.pm');
unlike(
  $dzt_wver,
  qr{^\s*\$\QDZT::WVer::DIST = 'DZT-Sample';\E\s*$}m,
  "*not* added to DZT::WVer; we have one already",
);

my $dzt_script_pkg = $tzil->slurp_file('build/bin/script_pkg.pl');
like(
    $dzt_script_pkg,
    qr{^\s*\$\QDZT::Script::DIST = 'DZT-Sample';\E\s*$}m,
    "added version to DZT::Script",
);

TODO: {
    local $TODO = 'only scanning for packages right now';
    my $dzt_script = $tzil->slurp_file('build/bin/script.pl');
    like(
        $dzt_script,
        qr{^\s*\$\QDZT::Script::DIST = 'DZT-Sample';\E\s*$}m,
        "added version to plain script",
    );
};

my $script_wver = $tzil->slurp_file('build/bin/script_ver.pl');
unlike(
    $script_wver,
    qr{^\s*\$\QDZT::WVer::DIST = 'DZT-Sample';\E\s*$}m,
    "*not* added to versioned DZT::Script; we have one already",
);

ok(
  grep({ m(skipping lib/DZT/WVer\.pm: assigns to \$DIST) }
    @{ $tzil->log_messages }),
  "we report the reason for no updateing WVer",
);

my $dzt_r1 = $tzil->slurp_file('build/lib/DZT/R1.pm');
my @matches = grep { /R1::DIST/ } split /\n/, $dzt_r1;
is(@matches, 1, "we add at most 1 DIST per package");

my $dzt_monkey = $tzil->slurp_file('build/lib/DZT/Monkey.pm');
unlike(
  $dzt_monkey,
  qr{\$DZT::TP2::DIST},
  "no version for DZT::TP2 when it looks like a monkey patch"
);

ok(
  grep({ m(skipping .+ DZT::TP2) } @{ $tzil->log_messages }),
  "we report the reason for not updating Monkey",
);

done_testing;

