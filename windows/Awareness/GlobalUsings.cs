// The WPF XAML compiler generates a temporary project (_wpftmp.csproj) that
// does not inherit implicit usings properly. These global using aliases ensure
// System.IO types are available and disambiguated from System.Windows.Shapes.Path.
global using Directory = System.IO.Directory;
global using File = System.IO.File;
global using Path = System.IO.Path;
global using MemoryStream = System.IO.MemoryStream;
