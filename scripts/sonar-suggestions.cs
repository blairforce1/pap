// sonar-suggestions.cs: prints the .globalconfig block that holds every
// SonarAnalyzer.CSharp rule at suggestion, for the .NET layer's bake-in.
// One line per rule the analyzer enables by default at warning or error,
// sorted by id. Run it after a SonarAnalyzer.CSharp version bump and
// replace the block in templates/dotnet/.globalconfig with its output:
//
//   dotnet run scripts/sonar-suggestions.cs -- \
//     ~/.nuget/packages/sonaranalyzer.csharp/<version>/analyzers/SonarAnalyzer.CSharp.dll
#:package Microsoft.CodeAnalysis.CSharp@4.14.0
#:property PublishAot=false

using System.Reflection;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Diagnostics;

if (args.Length != 1)
{
    Console.Error.WriteLine("usage: dotnet run scripts/sonar-suggestions.cs -- <SonarAnalyzer.CSharp.dll>");
    return 1;
}

Type[] types;
try
{
    types = Assembly.LoadFrom(args[0]).GetTypes();
}
catch (ReflectionTypeLoadException ex)
{
    // The code fixes need Microsoft.CodeAnalysis.Workspaces, which is not
    // referenced here; the analyzers load without it.
    types = [.. ex.Types.OfType<Type>()];
}

var ids = new SortedSet<string>(StringComparer.Ordinal);
foreach (var type in types.Where(t => !t.IsAbstract && typeof(DiagnosticAnalyzer).IsAssignableFrom(t)))
{
    if (type.GetConstructor(Type.EmptyTypes) is null)
    {
        continue;
    }
    var analyzer = (DiagnosticAnalyzer)Activator.CreateInstance(type)!;
    foreach (var d in analyzer.SupportedDiagnostics)
    {
        if (d.IsEnabledByDefault && d.DefaultSeverity >= DiagnosticSeverity.Warning)
        {
            ids.Add(d.Id);
        }
    }
}

foreach (var id in ids)
{
    Console.WriteLine($"dotnet_diagnostic.{id}.severity = suggestion");
}
Console.Error.WriteLine($"{ids.Count} rules");
return 0;
