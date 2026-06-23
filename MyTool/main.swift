import ArgumentParser
import Foundation

struct Canvas: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "canvas",
        abstract: "Canvas CLI for BYU–Hawaii."
    )

    func run() async throws {
        print(banner)
        print("Phase 2 scaffolding — subcommands coming online.")
    }
}

await Canvas.main()
