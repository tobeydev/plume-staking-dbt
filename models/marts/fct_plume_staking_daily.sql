{{ config(materialized='table') }}

-- Grain: one row per calendar day of Plume staking.
select
    staking_date,
    staking_month,
    amount_staked_plume,
    amount_staked_usd,
    stakers_count,
    implied_plume_price_usd,
    avg_stake_per_staker_plume,
    net_stake_change_plume,
    net_stake_change_pct,
    net_staker_change,
    net_flow_direction,
    staker_trend,
    move_size,
    net_stake_change_7d_avg_plume
from {{ ref('int_plume_staking_daily') }}
