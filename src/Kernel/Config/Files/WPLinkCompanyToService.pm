#Link in the admin interface
$Self->{'Frontend::Module'}->{'AdminCustomerCompanyService'} = {
  'Description' => 'Admin',
  'Group' => [
    'admin'
  ],
  'NavBarModule' => {
    'Block' => 'Customer',
    'Description' => 'Assign services to customer companies.',
    'Module' => 'Kernel::Output::HTML::NavBarModuleAdmin',
    'Name' => 'Customer Companies <-> Services',
    'Prio' => '550'
  },
  'NavBarName' => 'Admin',
  'Title' => 'Customer Company <-> Services'
};
