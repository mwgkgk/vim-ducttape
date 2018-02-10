package VIMx::Tie::Dict;

use strict;
use warnings;

use Carp 'croak';
use JSON::Tiny qw{ encode_json decode_json };
use Role::Tiny::With;
use VIMx::Util;

use base 'Tie::Hash';
with 'VIMx::Role::Tie';

# NOTE right now we only handle simple cases, where the value of the slot to
# be set/read is a plain scalar, a string or number.  We should probably
# refactor this to do the whole json {en,de}coding bit we're doing to handle
# @_ and a:000.

sub TIEHASH {
    my ($class, $dict, @opts) = @_;
    # ensure we exist
    vim_do(q{if !exists('} . vim_escape($dict) . "') | silent! let $dict = {} | endif");
    return bless { thing => $dict, @opts }, $class;
}

sub _make_target {
    my ($this, $key) = @_;
    my $dict = $this->{thing};

    # croak "VimL dicts cannot have numeric keys: $dict, $key"
    #     if "$key" =~ /^\d+$/;

    return "$dict"."['$key']";
}

sub _keys_hash {
    my ($this) = @_;
    my $dict = $this->{thing};

    my @keys = sort @{ vim_eval("keys($dict)") };

    ### @keys
    my $first = shift @keys;
    my $last  = pop @keys;

    my %keys = (
        $first,
        ( map { $_ => $_ } @keys ),
        ( defined $last ? ( $last, $last ) : () ),
        undef,
    );

    ### %keys
    return \%keys;
}

sub FIRSTKEY {
    my ($this) = @_;
    my $dict = $this->{thing};

    return vim_eval_raw("keys($dict)[0]");
}

sub NEXTKEY {
    my ($this, $prevkey) = @_;

    return _keys_hash($this)->{$prevkey};
}

sub SCALAR {
    my ($this) = @_;

    return vim_eval_raw("len(keys($this->{thing}))") // 0;
}

!!42;
__END__
