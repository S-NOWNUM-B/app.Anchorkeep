use anchor_lang::prelude::*;

declare_id!("Y8ik6bx8kAoeMr3Ugu7SmhKtvChTkBTd1hZLdWggHNg");

#[program]
pub mod vault_registry {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        ctx.accounts.counter.count = 0;
        ctx.accounts.counter.authority = ctx.accounts.payer.key();

        let cpi_accounts = anchor_lang::system_program::Transfer {
            from: ctx.accounts.payer.to_account_info(),
            to: ctx.accounts.counter.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(anchor_lang::system_program::ID, cpi_accounts);
        anchor_lang::system_program::transfer(cpi_ctx, HELLO_WORLD_LAMPORTS)?;

        msg!("Hello, world! Counter initialized");
        Ok(())
    }

    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.counter.authority,
            ctx.accounts.authority.key(),
            ErrorCode::Unauthorized,
        );
        require!(
            ctx.accounts.counter.count < MAX_COUNT,
            ErrorCode::CounterOverflow,
        );

        ctx.accounts.counter.count += 1;
        msg!("Hello, world! Counter is now {}", ctx.accounts.counter.count);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = 8 + Counter::INIT_SPACE,
        seeds = [COUNTER_SEED],
        bump
    )]
    pub counter: Account<'info, Counter>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Increment<'info> {
    #[account(mut, seeds = [COUNTER_SEED], bump)]
    pub counter: Account<'info, Counter>,
    pub authority: Signer<'info>,
}

pub mod constants {
    use super::*;

    #[constant]
    pub const COUNTER_SEED: &[u8] = b"counter";

    #[constant]
    pub const HELLO_WORLD_LAMPORTS: u64 = 1;

    #[constant]
    pub const MAX_COUNT: u64 = 10;
}

pub mod error {
    use super::*;

    #[error_code]
    pub enum ErrorCode {
        #[msg("Only the counter authority can update this counter")]
        Unauthorized,
        #[msg("Counter has reached the maximum value")]
        CounterOverflow,
    }
}

pub mod state {
    use super::*;

    #[account]
    #[derive(InitSpace)]
    pub struct Counter {
        pub count: u64,
        pub authority: Pubkey,
    }
}

use constants::*;
use error::ErrorCode;
use state::Counter;
