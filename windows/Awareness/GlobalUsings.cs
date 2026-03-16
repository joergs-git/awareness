// The WPF XAML compiler generates a temporary project (_wpftmp.csproj) that
// does not inherit implicit usings properly. These global using aliases ensure
// System.IO types are available. Note: System.IO.Path is NOT aliased here because
// System.Windows.Shapes.Path is used in ProgressWindow — files that need System.IO.Path
// use the fully qualified name instead.
global using Directory = System.IO.Directory;
global using File = System.IO.File;
global using MemoryStream = System.IO.MemoryStream;
