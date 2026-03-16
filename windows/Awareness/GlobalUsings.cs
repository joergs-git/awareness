// WinForms implicit usings (System.Drawing, System.Windows.Forms) are removed
// in the csproj to avoid type ambiguity with WPF. System.IO.Path is aliased
// to avoid collision with System.Windows.Shapes.Path in the WPF temp project.
global using Directory = System.IO.Directory;
global using File = System.IO.File;
global using Path = System.IO.Path;
global using MemoryStream = System.IO.MemoryStream;
