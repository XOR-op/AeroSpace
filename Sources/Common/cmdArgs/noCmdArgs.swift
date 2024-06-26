public struct FlattenWorkspaceTreeCmdArgs: RawCmdArgs, CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = noArgsParser(.flattenWorkspaceTree, allowInConfig: true)
}
public struct WorkspaceBackAndForthCmdArgs: RawCmdArgs, CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = noArgsParser(.workspaceBackAndForth, allowInConfig: true)
}
public struct ServerVersionInternalCommandCmdArgs: RawCmdArgs, CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = noArgsParser(.serverVersionInternalCommand, allowInConfig: false)
}

func noArgsParser<T: Copyable>(_ kind: CmdKind, allowInConfig: Bool) -> CmdParser<T> {
    cmdParser(
        kind: kind,
        allowInConfig: allowInConfig,
        help: """
            USAGE: \(kind) [-h|--help]

            OPTIONS:
              -h, --help   Print help
            """,
        options: [:],
        arguments: []
    )
}
