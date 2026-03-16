// Resolve ambiguous type references between System.Drawing (from UseWindowsForms)
// and System.Windows.Media (from WPF). WPF types are used everywhere in this app;
// System.Windows.Forms.Screen is only used for multi-monitor enumeration.
global using Color = System.Windows.Media.Color;
global using Brush = System.Windows.Media.Brush;
global using Brushes = System.Windows.Media.Brushes;
global using UserControl = System.Windows.Controls.UserControl;
global using Application = System.Windows.Application;
global using MouseEventArgs = System.Windows.Input.MouseEventArgs;
