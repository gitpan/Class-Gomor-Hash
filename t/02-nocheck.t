use Test;
BEGIN { plan(tests => 1) }

use Class::Gomor::Hash;
$Class::Gomor::Hash::NoCheck = 1;

ok(1);
