use anchor_lang::prelude::*;

declare_id!("Y8ik6bx8kAoeMr3Ugu7SmhKtvChTkBTd1hZLdWggHNg");

#[program]
pub mod vault_registry {
    use super::*;

    /// Создаёт запись сейфа. `version` — `revision` заверяемого файла (ADR 0006).
    pub fn initialize_vault(
        ctx: Context<InitializeVault>,
        vault_id: [u8; VAULT_ID_LEN],
        hash: [u8; HASH_LEN],
        version: u64,
    ) -> Result<()> {
        let record = &mut ctx.accounts.record;
        record.owner = ctx.accounts.owner.key();
        record.vault_id = vault_id;
        record.version = version;
        record.hash = hash;
        record.updated_at = Clock::get()?.unix_timestamp;
        record.bump = ctx.bumps.record;
        Ok(())
    }

    /// Заверяет новую версию файла. Версия только растёт: защита от гонок
    /// двух устройств и от заверения старого файла поверх нового.
    pub fn commit_version(
        ctx: Context<CommitVersion>,
        new_hash: [u8; HASH_LEN],
        new_version: u64,
    ) -> Result<()> {
        let record = &mut ctx.accounts.record;
        require!(new_version > record.version, ErrorCode::VersionMismatch);

        record.version = new_version;
        record.hash = new_hash;
        record.updated_at = Clock::get()?.unix_timestamp;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(vault_id: [u8; VAULT_ID_LEN])]
pub struct InitializeVault<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(
        init,
        payer = owner,
        space = 8 + VaultRecord::INIT_SPACE,
        seeds = [VAULT_SEED, owner.key().as_ref(), vault_id.as_ref()],
        bump
    )]
    pub record: Account<'info, VaultRecord>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CommitVersion<'info> {
    // Seeds берём из самой записи: чужой signer пройдёт проверку PDA,
    // но упадёт на has_one с понятной ошибкой Unauthorized
    #[account(
        mut,
        seeds = [VAULT_SEED, record.owner.as_ref(), record.vault_id.as_ref()],
        bump = record.bump,
        has_one = owner @ ErrorCode::Unauthorized
    )]
    pub record: Account<'info, VaultRecord>,
    pub owner: Signer<'info>,
}

pub mod constants {
    use super::*;

    #[constant]
    pub const VAULT_SEED: &[u8] = b"vault";

    // usize не экспортируется в IDL через #[constant], поэтому без атрибута

    /// Длина `vaultId` из заголовка `.akv`
    pub const VAULT_ID_LEN: usize = 16;

    /// SHA-256 всего `.akv`-файла
    pub const HASH_LEN: usize = 32;
}

pub mod error {
    use super::*;

    #[error_code]
    pub enum ErrorCode {
        #[msg("Only the vault owner can commit a new version")]
        Unauthorized,
        #[msg("New version must be greater than the anchored one")]
        VersionMismatch,
    }
}

pub mod state {
    use super::*;

    #[account]
    #[derive(InitSpace)]
    pub struct VaultRecord {
        pub owner: Pubkey,
        pub vault_id: [u8; VAULT_ID_LEN],
        /// `revision` заверенного файла (ADR 0006)
        pub version: u64,
        pub hash: [u8; HASH_LEN],
        pub updated_at: i64,
        pub bump: u8,
    }
}

use constants::*;
use error::ErrorCode;
use state::VaultRecord;
