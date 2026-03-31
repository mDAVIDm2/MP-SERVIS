export declare class LocalStorageService {
    private readonly root;
    putObject(storageKey: string, body: Buffer): Promise<void>;
    getAbsolutePath(storageKey: string): string;
    deleteObject(storageKey: string): Promise<void>;
    private resolveSafe;
}
