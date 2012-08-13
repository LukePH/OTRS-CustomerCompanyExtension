# --
# Kernel/Modules/AdminCustomerUserService.pm - to add/update/delete customeruserscompany <-> services
# Copyright (C) 2011-2011 Wuerth Phoenix
# Oreste Attanasio 11/2011
# --

package Kernel::Modules::AdminCustomerCompanyService;

use strict;
use warnings;

use Kernel::System::CustomerUser;
use Kernel::System::Service;
use Kernel::System::Valid;

#add needed object lib
use Kernel::System::CustomerCompany;
#add dumper
use Data::Dumper;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.24 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    for my $Needed (qw(ParamObject DBObject LayoutObject ConfigObject LogObject)) {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }
    $Self->{CustomerUserObject} = Kernel::System::CustomerUser->new(%Param);
    $Self->{ServiceObject}      = Kernel::System::Service->new(%Param);
    $Self->{ValidObject}        = Kernel::System::Valid->new(%Param);

    #create new CustomerCompany object
    $Self->{CustomerCompanyObject} = Kernel::System::CustomerCompany->new(%Param);
    
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %VisibleType = ( CustomerCompany => 'CustomerCompany', Service => 'Service', );

    # set search limit
    my $SearchLimit = 200;

    # ------------------------------------------------------------ #
    # allocate customer company 
    # OA: A customer company has been clicked
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'AllocateCustomerCompany' ) {

        # get params
        $Param{CustomerID} = $Self->{ParamObject}->GetParam( Param => 'CustomerID' )
            || '<DEFAULT>';
        $Param{CustomerCompanySearch} = $Self->{ParamObject}->GetParam( Param => 'CustomerCompanySearch' )
            || '*';

        # output header
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

	#####  we have to loop into every customer user associated with the company
	#
	# get all customer users for the given company... since we may have other customer backends defined, 
	# we may have also customer users NOT in the DB, therefore we can't just query the db... :(
	
	# Contains all customer users
 	my %AllUsers = $Self->{CustomerUserObject}->CustomerSearch(
		Search => '*',
	);
	
	# Contains all customernames	
	my @AllUserNames = keys %AllUsers;

	# Contains all customer users in the given company
	my @UsersInCompany = ();
	foreach(@AllUserNames) {
		my @CustomerIDs = $Self->{CustomerUserObject}->CustomerIDs( User => $_ );
		# company check
		if (grep $_ eq $Param{CustomerID}, @CustomerIDs) {
			push(@UsersInCompany, $_);	
		}
	}
	
	my $NoticeStr = scalar(@UsersInCompany) > 0 ? '' : $Self->{LayoutObject}->Notify(
		Priority => 'Notice',
		Data => 'There are no customers with CustomerID '.$Param{CustomerID}.'! Insert at least one user with CustomerID: '.$Param{CustomerID} . '! NO ASSOCIATION WILL BE DONE RIGHT NOW',
		Link => '$Env{"Baselink"}Action=AdminCustomerUser;Nav=Agent',
	);
	

	# Get all services associated to the company (by checking the services associated with the users)
	my $SQL = "SELECT scu.service_id as service_id, s.name as service_name "
        . "FROM service_customer_user scu, service s " 
	. "WHERE scu.service_id=s.id AND scu.customer_user_login IN ('" . join('\',\'', @UsersInCompany ) ."')" ;
	
	$Self->{DBObject}->Prepare(SQL => $SQL);

	my %ServiceMemberList;
	while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        	$ServiceMemberList{$Row[0]} = $Row[1];
	}

	# Test: should output all services associated with company
	#$Self->{LogObject}->Log( Priority => 'error', Message => Dumper(\%CompanyServices) );

        # List servces.
        my %ServiceData = $Self->{ServiceObject}->ServiceList(
            UserID => $Self->{UserID},
        );

        my $CustomerCompanyName
            = $Param{CustomerID} eq '<DEFAULT>' ? q{} : $Param{CustomerID};

        $Output .= $Self->_Change(
            ID                 => $Param{CustomerID},
            Name               => $CustomerCompanyName,
            Data               => \%ServiceData,
            Selected           => \%ServiceMemberList,
            CustomerUserSearch => $Param{CustomerCompanySearch},
            ServiceSearch      => $Param{ServiceSearch},
            SearchLimit        => $SearchLimit,
            Type               => 'CustomerCompany',
	    NoticeStr	       => $NoticeStr,
        );

        $Output .= $Self->{LayoutObject}->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # allocate service
    # OA: A service has been clieckd
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AllocateService' ) {

	#OA: Show companies instead of customer users (as of original module)	

        # get params
        $Param{ServiceID} = $Self->{ParamObject}->GetParam( Param => "ServiceID" );

        $Param{Subaction} = $Self->{ParamObject}->GetParam( Param => 'Subaction' );

        $Param{CustomerCompanySearch} = $Self->{ParamObject}->GetParam( Param => "CustomerCompanySearch" )
            || '*';

        # output header
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        # get service
        my %Service = $Self->{ServiceObject}->ServiceGet(
            ServiceID => $Param{ServiceID},
            UserID    => $Self->{UserID},
        );

		
        # get customer user member
	# OA: substitute this with the list of companies already associated with the clicked service
        my %CustomerUserMemberList = $Self->{ServiceObject}->CustomerUserServiceMemberList(
            ServiceID       => $Param{ServiceID},
            Result          => 'HASH',
            DefaultServices => 0,
        );
	# contains all companies associated with clicked service
	my %CustomerCompanyMemberList; #structure ??? (@see _Change() )
	my $SQL = "SELECT DISTINCT cu.customer_id " .
                               "FROM service_customer_user scu, customer_user cu, service s " .
                               "WHERE scu.customer_user_login = cu.login " .
                               "AND s.id = scu.service_id " .
                               "AND s.id = ? ";
		
	$Self->{LogObject}->Log( Priority => 'notice', Message => "SQL: " . $SQL );		

        $Self->{DBObject}->Prepare(SQL => $SQL, Bind => [\$Param{ServiceID}]);
	while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
		$Self->{LogObject}->Log( Priority => 'notice', Message => Dumper(@Row) );
	}

        # search customer user
	# OA: this should contain a list with all companies
        my %CustomerCompanyList
            = $Self->{CustomerUserObject}->CustomerSearch( Search => $Param{CustomerUserSearch}, );
            #= $Self->{CustomerCompanyObject}->CustomerCompanyList();
        my @CustomerCompanyKeyList
            = sort { $CustomerCompanyList{$a} cmp $CustomerCompanyList{$b} } keys %CustomerCompanyList;

        # set max count
        my $MaxCount = @CustomerCompanyKeyList;
        if ( $MaxCount > $SearchLimit ) {
            $MaxCount = $SearchLimit;
        }

        my %CustomerData;

        # output rows
        for my $Counter ( 1 .. $MaxCount ) {

            # get service
#            my %User = $Self->{CustomerUserObject}->CustomerUserDataGet(
#                User => $CustomerCompanyList[ $Counter - 1 ],
#            );
#            my $UserName = $Self->{CustomerUserObject}->CustomerName(
#                UserLogin => $CustomerCompanyKeyList[ $Counter - 1 ]
#            );
#            my $CustomerUser = "$UserName <$User{UserEmail}> ($User{UserCustomerID})";
#            $CustomerData{ $User{UserID} } = $CustomerUser;
        }

        $Output .= $Self->_Change(
            ID                 => $Param{ServiceID},
            Name               => $Service{Name},
            ItemList           => \@CustomerCompanyKeyList,
            Data               => \%CustomerData,
            Selected           => \%CustomerCompanyMemberList,
            CustomerUserSearch => $Param{CustomerCompanySearch},
            SearchLimit        => $SearchLimit,
            Type               => 'Service',
            %Param,
        );

        $Output .= $Self->{LayoutObject}->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # allocate customer user save
    # OA: Saves associations from AllocateCustomerCompany
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AllocateCustomerCompanySave' ) {

        # get params
        $Param{CustomerID} = $Self->{ParamObject}->GetParam( Param => 'ID' );

        $Param{CustomerCompanySearch} = $Self->{ParamObject}->GetParam( Param => 'CustomerCompanySearch' )
            || '*';

        my @ServiceIDsSelected = $Self->{ParamObject}->GetArray( Param => 'ItemsSelected' );
        my @ServiceIDsAll      = $Self->{ParamObject}->GetArray( Param => 'ItemsAll' );

        # create hash with selected ids
        my %ServiceIDSelected = map { $_ => 1 } @ServiceIDsSelected;

#	$Self->{LogObject}->Log( Priority => 'error', Message => Dumper(\%ServiceIDSelected));

	# OA: get all customeruserids (CustomerUserLogin) matching the company 
	#     then recursively apply $Self->{ServiceObject}->CustomerUserServiceMemberAdd(..) #see below

	# Contains all customer users
        my %AllUsers = $Self->{CustomerUserObject}->CustomerSearch(
                Search => '*',
        );

        # Contains all customernames    
        my @AllUserNames = keys %AllUsers;

        # Contains all customer users in the given company
        my @UsersInCompany = ();
        foreach(@AllUserNames) {
                my @CustomerIDs = $Self->{CustomerUserObject}->CustomerIDs( User => $_ );
                # company check
                if (grep $_ eq $Param{CustomerID}, @CustomerIDs) {
                        push(@UsersInCompany, $_);
                }
        }

        # check all used service ids
        for my $ServiceID (@ServiceIDsAll) {
            my $Active = $ServiceIDSelected{$ServiceID} ? 1 : 0;

            # set customer user service member
	    foreach(@UsersInCompany) {
		    $Self->{LogObject}->Log( Priority => 'debug', Message => 'Associate service '.$ServiceID.' to customer user ' . $_. ' of company ' . $Param{CustomerID} . ' with status ' . $Active );
        	    $Self->{ServiceObject}->CustomerUserServiceMemberAdd(
        	        CustomerUserLogin => $_,
        	        ServiceID         => $ServiceID,
        	        Active            => $Active,
        	        UserID            => $Self->{UserID},
        	    );
        	}
	}

        # redirect to overview
        return $Self->{LayoutObject}->Redirect(
            OP =>
                "Action=$Self->{Action};CustomerUserSearch=$Param{CustomerUserSearch}"
        );
    }

    # ------------------------------------------------------------ #
    # allocate service save
    # OA: Saves associations from AllocateService
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AllocateServiceSave' ) {

	# OA: Procedure: 
	#	1) Get all customer users of the given company
	#	2) Delete actual associations 
	#	3) Write updated associations


        # get params
        $Param{ServiceID} = $Self->{ParamObject}->GetParam( Param => "ID" );

        $Param{CustomerCompany} = $Self->{ParamObject}->GetParam( Param => 'CustomerCompanySearch' )
            || '*';

        my @CustomerCompanySelected
            = $Self->{ParamObject}->GetArray( Param => 'ItemsSelected' );
        my @CustomerCompanyAll
            = $Self->{ParamObject}->GetArray( Param => 'ItemsAll' );

        # create hash with selected customer companies
        my %CustomerCompanySelected;
        for my $CustomerCompany (@CustomerCompanySelected) {
            $CustomerCompanySelected{$CustomerCompany} = 1;
        }

        # check all used customer companies
        for my $CustomerCompany (@CustomerCompanyAll) {
            my $Active = $CustomerCompanySelected{$CustomerCompany} ? 1 : 0;
#		OA: LOOP HERE !!!
            # set customer user service member
       #     $Self->{ServiceObject}->CustomerUserServiceMemberAdd(
       #         CustomerUserLogin => $CustomerUserLogin,
       #         ServiceID         => $Param{ServiceID},
       #         Active            => $Active,
       #         UserID            => $Self->{UserID},
       #     );
        }

        # redirect to overview
        return $Self->{LayoutObject}->Redirect(
            OP =>
                "Action=$Self->{Action};CustomerUserSearch=$Param{CustomerUserSearch}"
        );
    }

    # ------------------------------------------------------------ #
    # overview
    # OA: La schermata iniziale del modulo
    #     Sostituisco CustomerUser* con CustomerCompany*
    # ------------------------------------------------------------ #
    else {

        # get params
        $Param{CustomerCompanySearch} = $Self->{ParamObject}->GetParam( Param => 'CustomerCompanySearch' )
            || '*';

        # output header
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        # search customer company
        my %CustomerCompanyList
            = $Self->{CustomerCompanyObject}->CustomerCompanyList( Search => $Param{CustomerCompanySearch}, );

	## OCCHIO COS'E' sta roba??? 
        my @CustomerCompanyKeyList
            = sort { $CustomerCompanyList{$a} cmp $CustomerCompanyList{$b} } keys %CustomerCompanyList;

        # count results
        my $CustomerCompanyCount = @CustomerCompanyKeyList;

        # set max count
        my $MaxCustomerCount = $CustomerCompanyCount;

        if ( $MaxCustomerCount > $SearchLimit ) {
            $MaxCustomerCount = $SearchLimit;
        }

        # output rows
        my %CompanyRowParam;
        for my $Counter ( 1 .. $MaxCustomerCount ) {

            # set customer user row params
            if ( defined( $CustomerCompanyKeyList[ $Counter - 1 ] ) ) {

                # Get company details
		# OA: raccolgo dati sul customer company
                my %Company = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
                    CustomerID => $CustomerCompanyKeyList[ $Counter - 1 ]
                );
                #my $UserName = $Self->{CustomerUserObject}->CustomerName(
                #    UserLogin => $CustomerUserKeyList[ $Counter - 1 ]
                #);
                $CompanyRowParam{$Company{CustomerID}}
                    = "$Company{CustomerCompanyName} ($Company{CustomerID})";
		#check!
            }
        }

        my %ServiceData = $Self->{ServiceObject}->ServiceList(
            UserID => $Self->{UserID},
        );

        $Output .= $Self->_Overview(
            CustomerCompanyCount   => $CustomerCompanyCount,
            CustomerCompanyKeyList => \@CustomerCompanyKeyList,
            CustomerCompanyData    => \%CompanyRowParam,
            ServiceData         => \%ServiceData,
            SearchLimit         => $SearchLimit,
            CustomerCompanySearch  => $Param{CustomerCompanySearch},
        );

        $Output .= $Self->{LayoutObject}->Footer();

        return $Output;
    }
}

sub _Change {
    my ( $Self, %Param ) = @_;

#        $Output .= $Self->_Change(
#            ID                 => $Param{CustomerID},
#            Name               => $CustomerCompanyName,
#            Data               => \%ServiceData,
#            Selected           => \%ServiceMemberList,
#            CustomerCompanySearch => $Param{CustomerCompanySearch},
#            ServiceSearch      => $Param{ServiceSearch},
#            SearchLimit        => $SearchLimit,
#            Type               => 'CustomerCompany',
#        );

    # OA: added $NoticeStr to handle error and/or notices
    my $NoticeStr   = $Param{NoticeStr} | '';
    my $SearchLimit = $Param{SearchLimit};
    my %Data        = %{ $Param{Data} };
    my $Type        = $Param{Type} || 'CustomerCompany';
    my $NeType      = $Type eq 'Service' ? 'CustomerCompany' : 'Service';
    my %VisibleType = ( CustomerCompany => 'CustomerCompany', Service => 'Service', );
    my %Subaction   = ( CustomerCompany => 'Change', Service => 'ServiceEdit', );
    my %IDStrg      = ( CustomerCompany => 'CustomerID', Service => 'ServiceID', );

    my @ItemList = ();

    # overview
    $Self->{LayoutObject}->Block( Name => 'Overview' );
    $Self->{LayoutObject}->Block( Name => 'ActionList' );
    $Self->{LayoutObject}->Block(
        Name => 'ActionOverview',
        Data => {
            CustomerCompanySearch => $Param{CustomerCompanySearch},
            }
    );

    if ( $NeType eq 'CustomerCompany' ) {
        @ItemList = @{ $Param{ItemList} };

        # output search block
        $Self->{LayoutObject}->Block(
            Name => 'Search',
            Data => {
                %Param,
                CustomerCompanySearch => $Param{CustomerCompanySearch},
            },
        );
        $Self->{LayoutObject}->Block(
            Name => 'SearchAllocateService',
            Data => {
                %Param,
                Subaction => $Param{Subaction},
                ServiceID => $Param{ServiceID},
            },
        );
    }
    else {
        $Self->{LayoutObject}->Block( Name => 'Filter' );
    }

    $Self->{LayoutObject}->Block(
        Name => 'AllocateItem',
        Data => {
            ID              => $Param{ID},
            ActionHome      => 'Admin' . $Type,
            Type            => $Type,
            NeType          => $NeType,
            VisibleType     => $VisibleType{$Type},
            VisibleNeType   => $VisibleType{$NeType},
            SubactionHeader => $Subaction{$Type},
            IDHeaderStrg    => $IDStrg{$Type},
            %Param,
        },
    );

    $Self->{LayoutObject}->Block( Name => "AllocateItemHeader$VisibleType{$NeType}" );

    if ( $NeType eq 'CustomerCompany' ) {

        # output count block
        if ( !@ItemList ) {
            $Self->{LayoutObject}->Block(
                Name => 'AllocateItemCountLimit',
                Data => { ItemCount => 0, },
            );

            my $ColSpan = "2";

            $Self->{LayoutObject}->Block(
                Name => 'NoDataFoundMsg',
                Data => {
                    ColSpan => $ColSpan,
                },
            );
        }
        elsif ( @ItemList > $SearchLimit ) {
            $Self->{LayoutObject}->Block(
                Name => 'AllocateItemCountLimit',
                Data => { ItemCount => ">" . $SearchLimit, },
            );
        }
        else {
            $Self->{LayoutObject}->Block(
                Name => 'AllocateItemCount',
                Data => { ItemCount => scalar @ItemList, },
            );
        }
    }

    # Service sorting.
    my %ServiceData;
    if ( $NeType eq 'Service' ) {
        %ServiceData = %Data;

        # add suffix for correct sorting
        for my $DataKey ( keys %Data ) {
            $Data{$DataKey} .= '::';
        }

    }

    # output rows
    for my $ID ( sort { uc( $Data{$a} ) cmp uc( $Data{$b} ) } keys %Data ) {

        # set checked
        my $Checked = $Param{Selected}->{$ID} ? "checked='checked'" : '';

        # Recover original Service Name
        if ( $NeType eq 'Service' ) {
            $Data{$ID} = $ServiceData{$ID};
        }

        # output row block
        $Self->{LayoutObject}->Block(
            Name => 'AllocateItemRow',
            Data => {
                ActionNeHome => 'Admin' . $NeType,
                Name         => $Data{$ID},
                ID           => $ID,
                Checked      => $Checked,
                SubactionRow => $Subaction{$NeType},
                IDRowStrg    => $IDStrg{$NeType},

            },
        );
    }

    # OA: print noticeStr if present
    # generate output
    return $NoticeStr.$Self->{LayoutObject}->Output(
        TemplateFile => 'AdminCustomerCompanyService',
        Data         => \%Param,
    );
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $CustomerCompanyCount   = $Param{CustomerCompanyCount};
    my @CustomerCompanyKeyList = @{ $Param{CustomerCompanyKeyList} };
    my $SearchLimit         = $Param{SearchLimit};
    my %CustomerCompanyData    = %{ $Param{CustomerCompanyData} };
    my %ServiceData         = %{ $Param{ServiceData} };

    $Self->{LayoutObject}->Block( Name => 'Overview' );
    $Self->{LayoutObject}->Block( Name => 'ActionList' );

    # output search block
    $Self->{LayoutObject}->Block(
        Name => 'Search',
        Data => {
            %Param,
            CustomerCompanySearch => $Param{CustomerCompanySearch},
        },
    );
    $Self->{LayoutObject}->Block( Name => 'Default', );

    # output filter and default block
    $Self->{LayoutObject}->Block( Name => 'Filter', );

    # output result block
    $Self->{LayoutObject}->Block(
        Name => 'Result',
        Data => {
            %Param,
            CustomeriCompanyCount => $CustomerCompanyCount,
        },
    );

    # output customer user count block
    if ( !@CustomerCompanyKeyList ) {
        $Self->{LayoutObject}->Block(
            Name => 'ResultCustomerCompanyCountLimit',
            Data => { CustomerCompanyCount => 0, },
        );

        $Self->{LayoutObject}->Block(
            Name => 'NoDataFoundMsgList',
        );
    }
    elsif ( @CustomerCompanyKeyList > $SearchLimit ) {
        $Self->{LayoutObject}->Block(
            Name => 'ResultCustomerCompanyCountLimit',
            Data => { CustomerCompanyCount => ">" . $SearchLimit, },
        );
    }
    else {
        $Self->{LayoutObject}->Block(
            Name => 'ResultCustomerCompanyCount',
            Data => { CustomerCompanyCount => scalar @CustomerCompanyKeyList, },
        );
    }

    for my $ID (
        sort { uc( $CustomerCompanyData{$a} ) cmp uc( $CustomerCompanyData{$b} ) }
        keys %CustomerCompanyData
        )
    {

        # output user row block
        $Self->{LayoutObject}->Block(
            Name => 'ResultUserRow',
            Data => {
                %Param,
                ID   => $ID,
                Name => $CustomerCompanyData{$ID},
            },
        );
    }

    my %ServiceDataSort = %ServiceData;

    # add suffix for correct sorting
    for my $ServiceDataKey ( keys %ServiceDataSort ) {
        $ServiceDataSort{$ServiceDataKey} .= '::';
    }

    for my $ID (
        sort { uc( $ServiceDataSort{$a} ) cmp uc( $ServiceDataSort{$b} ) }
        keys %ServiceDataSort
        )
    {

        # output service row block
        $Self->{LayoutObject}->Block(
            Name => 'ResultServiceRow',
            Data => {
                %Param,
                ID   => $ID,
                Name => $ServiceData{$ID},
            },
        );
    }

    # generate output
    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminCustomerCompanyService',
        Data         => \%Param,
    );
}
1;
