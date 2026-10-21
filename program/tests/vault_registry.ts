import * as anchor from "@anchor-lang/core";
import { AnchorError, Program } from "@anchor-lang/core";
import { expect } from "chai";
import { randomBytes } from "crypto";
import { VaultRegistry } from "../target/types/vault_registry";

describe("vault_registry", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.vaultRegistry as Program<VaultRegistry>;
  const owner = provider.wallet.publicKey;

  const recordPda = (vaultId: Buffer, authority = owner) =>
    anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault"), authority.toBuffer(), vaultId],
      program.programId
    )[0];

  const sha = () => Array.from(randomBytes(32));

  // Создаёт новую запись со случайным vault_id, чтобы тесты не зависели друг от друга
  const initVault = async (version: number, hash = sha()) => {
    const vaultId = randomBytes(16);
    await program.methods
      .initializeVault(Array.from(vaultId), hash, new anchor.BN(version))
      .accounts({ owner })
      .rpc();
    return { vaultId, record: recordPda(vaultId), hash };
  };

  // Ожидает AnchorError с нужным кодом
  const expectError = async (promise: Promise<unknown>, code: string) => {
    try {
      await promise;
      expect.fail(`ожидалась ошибка ${code}`);
    } catch (e) {
      expect(e).to.be.instanceOf(AnchorError);
      expect((e as AnchorError).error.errorCode.code).to.equal(code);
    }
  };

  it("initialize_vault создаёт запись с переданными полями", async () => {
    const { vaultId, record, hash } = await initVault(42);

    const account = await program.account.vaultRecord.fetch(record);
    expect(account.owner.toBase58()).to.equal(owner.toBase58());
    expect(account.vaultId).to.deep.equal(Array.from(vaultId));
    expect(account.version.toNumber()).to.equal(42);
    expect(account.hash).to.deep.equal(hash);
    expect(account.updatedAt.toNumber()).to.be.greaterThan(0);
  });

  it("повторный initialize_vault для того же vault_id падает", async () => {
    const { vaultId } = await initVault(1);

    let failed = false;
    try {
      await program.methods
        .initializeVault(Array.from(vaultId), sha(), new anchor.BN(2))
        .accounts({ owner })
        .rpc();
    } catch {
      failed = true;
    }
    expect(failed).to.equal(true);
  });

  it("commit_version обновляет хеш и версию", async () => {
    const { record } = await initVault(5);
    const newHash = sha();

    await program.methods
      .commitVersion(newHash, new anchor.BN(9))
      .accounts({ record })
      .rpc();

    const account = await program.account.vaultRecord.fetch(record);
    expect(account.version.toNumber()).to.equal(9);
    expect(account.hash).to.deep.equal(newHash);
  });

  it("commit_version с той же версией → VersionMismatch", async () => {
    const { record } = await initVault(5);

    await expectError(
      program.methods
        .commitVersion(sha(), new anchor.BN(5))
        .accounts({ record })
        .rpc(),
      "VersionMismatch"
    );
  });

  it("commit_version со старой версией → VersionMismatch", async () => {
    const { record, hash } = await initVault(5);

    await expectError(
      program.methods
        .commitVersion(sha(), new anchor.BN(4))
        .accounts({ record })
        .rpc(),
      "VersionMismatch"
    );

    // Запись не изменилась
    const account = await program.account.vaultRecord.fetch(record);
    expect(account.version.toNumber()).to.equal(5);
    expect(account.hash).to.deep.equal(hash);
  });

  it("commit_version чужим signer → Unauthorized", async () => {
    const { record } = await initVault(5);
    const stranger = anchor.web3.Keypair.generate();

    // Комиссию платит provider wallet, stranger только подписывает как owner
    await expectError(
      program.methods
        .commitVersion(sha(), new anchor.BN(6))
        .accountsPartial({ record, owner: stranger.publicKey })
        .signers([stranger])
        .rpc(),
      "Unauthorized"
    );
  });
});
