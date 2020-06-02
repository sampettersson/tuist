import TSCBasic
import TuistSupport

/// Controller for command line utility `security`
protocol SecurityControlling {
    func decodeFile(at path: AbsolutePath) throws -> String
    func importCertificate(_ certificate: Certificate, keychainPath: AbsolutePath) throws
    func createKeychain(at path: AbsolutePath, password: String) throws
    func unlockKeychain(at path: AbsolutePath, password: String) throws
    func lockKeychain(at path: AbsolutePath, password: String) throws
}

final class SecurityController: SecurityControlling {
    func decodeFile(at path: AbsolutePath) throws -> String {
        try System.shared.capture("/usr/bin/security", "cms", "-D", "-i", path.pathString)
    }
    
    func importCertificate(_ certificate: Certificate, keychainPath: AbsolutePath) throws {
        if try !certificateExists(at: certificate.publicKey) {
            try importToKeychain(at: certificate.publicKey, keychainPath: keychainPath)
        }
        if try !keyExists(at: certificate.privateKey) {
            try importToKeychain(at: certificate.privateKey, keychainPath: keychainPath)
        }
        logger.debug("Imported certificate at \(certificate.publicKey.pathString)")
    }
    
    func createKeychain(at path: AbsolutePath, password: String) throws {
        do {
            try System.shared.run("/usr/bin/security", "create-keychain", "-p", password, path.pathString)
        } catch {
            if let systemError = error as? TuistSupport.SystemError,
                systemError.description.contains("A keychain with the same name already exists.") {
                logger.debug("Keychain at \(path.pathString) already exists")
                return
            } else {
                throw error
            }
        }
        logger.debug("Created keychain at \(path.pathString)")
    }
    
    func unlockKeychain(at path: AbsolutePath, password: String) throws {
        try System.shared.run("/usr/bin/security", "unlock-keychain", "-p", password, path.pathString)
        logger.debug("Unlocked keychain at \(path.pathString)")
    }
    
    func lockKeychain(at path: AbsolutePath, password: String) throws {
        try System.shared.run("/usr/bin/security", "lock-keychain", "-p", password, path.pathString)
        logger.debug("Locked keychain at \(path.pathString)")
    }
    
    // MARK: - Helpers
    
    private func keyExists(at path: AbsolutePath) throws -> Bool {
        do {
            try System.shared.run("/usr/bin/security", "find-key", path.pathString, "-P", "")
            return true
        } catch {
            return false
        }
    }
    
    private func certificateExists(at path: AbsolutePath) throws -> Bool {
        do {
            try System.shared.run("/usr/bin/security", "find-certificate", path.pathString, "-P", "")
            return true
        } catch {
            return false
        }
    }
    
    private func importToKeychain(at path: AbsolutePath, keychainPath: AbsolutePath) throws {
        try System.shared.run("/usr/bin/security", "import", path.pathString, "-P", "", "-k", keychainPath.pathString)
    }
}
