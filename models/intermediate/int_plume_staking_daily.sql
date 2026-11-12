-- Decisions live here:
--  * recompute day-over-day change from the data (provider growth columns are
--    zero-filled at the start of the series, so they are dropped from here on)
--  * first row has no prior day -> labelled 'baseline', changes set to 0
--  * classify flow direction / staker trend / move size using dbt vars
--  * derive implied price and average stake per staker
with stg as (

    select * from {{ ref('stg_plume_staking') }}

),

lagged as (

    select
        staking_date,
        amount_staked_plume,
        amount_staked_usd,
        stakers_count,
        lag(amount_staked_plume) over w as prev_amount_staked_plume,
        lag(stakers_count)       over w as prev_stakers_count
    from stg
    window w as (order by staking_date)

),

changes as (

    select
        *,
        coalesce(amount_staked_plume - prev_amount_staked_plume, 0) as net_stake_change_plume,
        coalesce(
            100.0 * (amount_staked_plume - prev_amount_staked_plume)
            / nullif(prev_amount_staked_plume, 0), 0
        ) as net_stake_change_pct,
        coalesce(stakers_count - prev_stakers_count, 0) as net_staker_change
    from lagged

)

select
    staking_date,
    date_trunc('month', staking_date)::date as staking_month,
    amount_staked_plume,
    amount_staked_usd,
    stakers_count,
    round(amount_staked_usd / nullif(amount_staked_plume, 0), 6)  as implied_plume_price_usd,
    round(amount_staked_plume / nullif(stakers_count, 0), 2)      as avg_stake_per_staker_plume,
    net_stake_change_plume,
    round(net_stake_change_pct, 4)                                as net_stake_change_pct,
    net_staker_change,
    case
        when prev_amount_staked_plume is null                         then 'baseline'
        when net_stake_change_pct >=  {{ var('flow_threshold_pct') }} then 'inflow'
        when net_stake_change_pct <= -{{ var('flow_threshold_pct') }} then 'outflow'
        else 'flat'
    end as net_flow_direction,
    case
        when prev_stakers_count is null           then 'baseline'
        when net_staker_change > 0                then 'growing'
        when net_staker_change < 0                then 'shrinking'
        else 'stable'
    end as staker_trend,
    case
        when prev_amount_staked_plume is null                           then 'baseline'
        when abs(net_stake_change_pct) >= {{ var('large_move_pct') }}   then 'large'
        else 'normal'
    end as move_size,
    round(avg(net_stake_change_plume) over (
        order by staking_date rows between 6 preceding and current row
    ), 2) as net_stake_change_7d_avg_plume
from changes
