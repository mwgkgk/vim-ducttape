if has('g:ducttape_loaded')
    finish
endif
let g:ducttape_loaded = 1

execute ':perl push @INC, q{' . expand('<sfile>:h') . '/../lib}'

finish

perl <<EOP
# line 12 "plugin/ducttape.vim"

use v5.10;
use strict;
use warnings;

# push onto @INC, but only once
BEGIN {
    my $base = VIM::Eval('expand("<sfile>:h")') . '/..';

    push @INC,
        # note the $_'s are *different* in the following line
        grep { ! { map { $_ => 1 } @INC }->{$_} }
        "$base/lib",
        ;
}

use VIMx::Out;

# again, somethings we only ever need to do once...
unless (tied *VIMOUT) {
    tie (*VIMOUT, 'VIMx::Out');
    tie (*VIMERR, 'VIMx::Out', 'ErrorMsg');
    select VIMOUT;
}

EOP

" __END__
