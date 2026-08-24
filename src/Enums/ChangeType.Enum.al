enum 50000 "Data Debugger Change Type"
{
    Extensible = false;

    value(0; Insert)
    {
        Caption = 'Insert';
    }
    value(1; Modify)
    {
        Caption = 'Modify';
    }
    value(2; Delete)
    {
        Caption = 'Delete';
    }
    value(3; Rename)
    {
        Caption = 'Rename';
    }
    value(4; Error)
    {
        Caption = 'Error';
    }
}