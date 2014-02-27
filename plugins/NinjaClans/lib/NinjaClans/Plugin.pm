package NinjaClans::Plugin;
use strict;
use warnings;

sub _get_user {
    my $app = shift;
    my $user;
    {
        local $@;
        eval { $user = $app->user() };
    }
    return unless $user;
    return if $user->is_superuser();
    return $user;
}

sub add_to_clan {
    my ($cb, $obj) = @_;
    return 1 if $obj->id;
    my $app = MT->instance;
    my $user = _get_user($app) 
        or return 1;
    my $clan = $user->clan();
    $obj->clan( $clan );
    return 1;
}

sub see_only_clan {
    my ($cb, $class, $terms, $args) = @_;
    my $app = MT->instance;
    my $user = _get_user($app) 
        or return 1;
    my $clan = $user->clan();
    if (defined $terms and not ref $terms) {
        return 1;
    }
    my $clan_str = 'is NULL';
    $clan_str .= " OR author_clan=\"$clan\"" if defined $clan;
    $terms->{clan} = \$clan_str;
    return 1;
}

sub template_param_edit_author {
    my ($cb, $app, $params, $tmpl) = @_;

    my $user = $app->user;
    return 1 unless $user->is_superuser();
    my $author;
    if (my $id = $params->{id}) {
        $author = $app->model('author')->load($id);
    }
    return 1 if $author and $author->is_superuser();

    my $plugin = $app->component('NinjaClans');
    my $clans = $plugin->get_config_value('clans');
    my @clans = grep { defined $_ and length $_ } split /\s*,\s*/, $clans;

    my ($place)
        = grep { $_->attributes->{name} eq 'action_buttons' }
        @{ $tmpl->getElementsByTagName('setvarblock') };
    return 1 unless $place;
    my $settings = $tmpl->createElement( 'app:setting', { 
        id => 'user_clan',
        label => 'User Clan',
        hint => 'This user will only see others from his clan',
        show_hint => 1,
        });

    my $clan = $author ? $author->clan : undef;
    my $selected = 'selected="selected"';
    my $select = '<select name="user_clan" id="user_clan">';
    if (not $clan) {
        $select .= "<option value=\"\" $selected>(none)</option>";
    } else {
        $select .= '<option value="">(none)</option>';
    }
    require MT::Util;
    foreach my $clan_label (@clans) {
        my $e_clan = MT::Util::encode_html($clan_label);
        if ($clan and $clan eq $clan_label) {
            $select .= "<option value=\"$e_clan\" $selected>$e_clan</option>";
        }
        else {
            $select .= "<option value=\"$e_clan\">$e_clan</option>";
        }
    }
    $select .= '</select>';

    my $select_node = $tmpl->createTextNode( $select );
    $settings->appendChild($select_node);
    $tmpl->insertBefore( $settings, $place );
    return 1;
}

sub author_pre_save {
    my ($cb, $app, $obj, $original) = @_;
    my $user = $app->user;
    return 1 unless $user->is_superuser();
    return 1 if $obj->id and $obj->is_superuser();
    my $clan = $app->param('user_clan');

    my $plugin = $app->component('NinjaClans');
    my $clans = $plugin->get_config_value('clans');
    my @clans = grep { defined $_ and length $_ } split /\s*,\s*/, $clans;
    if ( not defined $clan or $clan eq '' ) {
        $clan = undef;
    } 
    else {
        $clan = undef unless grep { $clan eq $_ } @clans;
    }
    $obj->clan( $clan );
    return 1;
}

sub init_app {
    my ( $cb, $app ) = @_;
    use MT::Author;
    my $props = MT::Author->properties();
    push @{$props->{columns}}, 'clan';
    $props->{column_defs}{clan} = { type => 'string', size => '30' };
    $props->{column_names}{clan} = 1;
    return 1;
}

1;
