package VIMx::Symbiont;

# ABSTRACT: Co-dependent Perl

# Some notes, before we get started:
#
# For portability's sake, use as few external packages as possible: the whole
# idea is to be able to just drop this in and use it, after all. The ::Tiny
# ones are generally fine, as they can be included as submodules, but XS is
# "right out".


use strict;
use warnings;

use Path::Tiny;
use JSON::Tiny qw{ encode_json decode_json };
use Try::Tiny;
use VIMx::Tie::Dict;

use parent 'Exporter';

# also JSON::Tiny, for convenience
our @EXPORT = qw/
    decode_json
    encode_json

    function
    fun

    %a %b %g %l %s %t %v %w
/;

# see help for internal-variables for more information
tie our %a, 'VIMx::Tie::Dict', 'a:';
tie our %b, 'VIMx::Tie::Dict', 'b:';
tie our %g, 'VIMx::Tie::Dict', 'g:';
tie our %l, 'VIMx::Tie::Dict', 'l:';
tie our %s, 'VIMx::Tie::Dict', 's:';
tie our %t, 'VIMx::Tie::Dict', 't:';
tie our %v, 'VIMx::Tie::Dict', 'v:';
tie our %w, 'VIMx::Tie::Dict', 'w:';

# may as well make life a little easier at the command prompt
$main::a = \%a;
$main::b = \%b;
$main::g = \%g;
$main::l = \%l;
$main::s = \%s;
$main::t = \%t;
$main::v = \%v;
$main::w = \%w;

our %VIML;
$g{vimx_symbiont_viml} = {};

our %RETURN;
$g{vimx_symbiont_return} = {};

sub _class_to_vim_ns { (my $ns = shift) =~ s/::/#/g; $ns }


tie our %vimx_return, 'VIMx::Tie::Dict', 'g:vimx_symbiont_return';
tie our %vimx_viml,   'VIMx::Tie::Dict', 'g:vimx_symbiont_viml';

# NOTE: when using the args option, the named parameters must be accessed
# through the %a tie.

sub function {
    my ($coderef, $name) = (pop, pop);
    my %opts = (
        args => '...',
        opts => 'abort',
        @_,
    );

    # TODO just return if we're not inside vim

    my ($pkg) = caller;
    my $perl_name = "${pkg}::func_${name}";
    my $vim_ns    = _class_to_vim_ns($pkg);
    $name = _class_to_vim_ns($pkg) . "#$name";

    my $return_var = "g:vimx_symbiont_return['$name']";

    my $viml = <<"END";
function! $name($opts{args}) $opts{opts}
    perl ${perl_name}(scalar VIM::Eval('json_encode(a:000)'))
    return json_decode($return_var)
endfunction
END

    my $wrapped = sub {
        # vivify our args, execute the coderef, etc
        my @a000 = @{ decode_json(scalar VIM::Eval('json_encode(a:000)')) };
        try {
            ( $RETURN{$name} = encode_json($coderef->(@a000)) ) =~ s/'/''/g;

            # handle getting the return value(s) back into vim-land
            VIM::DoCommand("let $return_var = '$RETURN{$name}'");
        }
        catch {
            $_ =~ s/'/''/g;
            VIM::DoCommand("throw '$_'");
        };

        return;
    };

    $VIML{$pkg} //= <<"END";
let g:$vim_ns#loaded = 1
fun! $vim_ns#load() abort
endfun
END

    # optimize later -- some cruft built up here
    $VIML{$pkg}  .= $viml;
    $vimx_viml{$pkg} = $VIML{$pkg};

    {
        no strict 'refs';
        *{$perl_name} = $wrapped;
    }

    return;
}

# shorthand
sub fun { goto \&function }

!!42;
__END__
