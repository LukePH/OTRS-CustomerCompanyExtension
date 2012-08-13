#Link in the admin interface
$Self->{'Frontend::Module'}->{'AdminCustomerCompanyGroup'} = {
  'Description' => 'Admin',
  'Group' => [
    'admin'
  ],
  'NavBarModule' => {
    'Block' => 'Customer',
    'Description' => 'Assign customer companies to groups.',
    'Module' => 'Kernel::Output::HTML::NavBarModuleAdmin',
    'Name' => 'Customer Companies <-> Groups',
    'Prio' => '550'
  },
  'NavBarName' => 'Admin',
  'Title' => 'Customer Company <-> Groups'
};
$Self->{'WPCustomerCompanyExtension::GroupBlacklist'} = ['users','stats','admin'];
