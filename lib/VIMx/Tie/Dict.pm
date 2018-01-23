package VIMx::Tie::Dict;

use strict;
use warnings;

use JSON::Tiny qw{ encode_json decode_json };

use base 'Tie::Hash';

# # debugging...
# use Smart::Comments '###';

# NOTE right now we only handle simple cases, where the value of the slot to
# be set/read is a plain scalar, a string or number.  We should probably
# refactor this to do the whole json {en,de}coding bit we're doing to handle
# @_ and a:000.

sub TIEHASH {
    my ($class, $dict) = @_;
    # ensure we exist
    VIM::DoCommand("if !exists('$dict') | let $dict = {} | endif");
    return bless { thing => $dict }, $class;
}

sub STORE {
    my ($this, $key, $value) = @_;
    my $dict = $this->{thing};

    my $target = "$dict"."['$key']";

    if ((ref $value // q{}) eq 'SCALAR') {
        # we've been passed a reference to a scalar
        # much like DBIC, this means "execute this literally"
        VIM::DoCommand("let $target = $$value");
        return FETCH($this, $key);
    }

    (my $viml_value = encode_json($value)) =~ s/'/''/g;

    #### STORE: "$target = json_decode('$viml_value')"
    VIM::DoCommand("let $target = json_decode('$viml_value')");
    return $value;
}

sub FETCH {
    my ($this, $key) = @_;
    my $dict = $this->{thing};

    # conform to expected behaviour: vim will complain if a slot that does not
    # exist is accessed, while Perl will simply return undef.  Here we
    # short-circuit to return undef.
    return
        unless EXISTS($this, $key);

    my ($success, $v) = VIM::Eval("json_encode(get($dict, '$key'))");
    return decode_json($v);
}

sub EXISTS {
    my ($this, $key) = @_;
    my $dict = $this->{thing};
    my ($success, $v) = VIM::Eval("has_key($dict, '$key')");
    return !!$v;
}

sub DELETE {
    my ($this, $key) = @_;
    my $dict = $this->{thing};
    my $value = FETCH($this, $key);
    VIM::DoCommand("unlet! $dict"."['$key']");
    return $value;
}

sub _keys_hash {
    my ($this) = @_;
    my $dict = $this->{thing};

    my ($success, $v) = VIM::Eval("json_encode(keys($dict))");
    my @keys          = sort @{ decode_json($v) };

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

    my ($success, $v) = VIM::Eval("len(keys($dict))");
    return unless $v;

    ($success, $v) = VIM::Eval("keys($dict)[0]");
    return $v;
}

sub NEXTKEY {
    my ($this, $prevkey) = @_;

    return _keys_hash($this)->{$prevkey};
}

!!42;
__END__
