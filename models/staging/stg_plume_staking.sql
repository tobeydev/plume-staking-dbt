-- Clean, cast, rename only. No business logic.
select
    cast("date" as date)                           as staking_date,
    cast(amount_staked as numeric)                 as amount_staked_plume,
    cast(amount_staked_usd as numeric)             as amount_staked_usd,
    cast(amount_staked_growth_24h as numeric)      as amount_staked_growth_24h_pct,
    cast("amount_staked_growth_7D" as numeric)       as amount_staked_growth_7d_pct,
    cast("amount_staked_growth_30D" as numeric)      as amount_staked_growth_30d_pct,
    cast(stakers as integer)                       as stakers_count,
    cast(stakers_growth_24h as numeric)            as stakers_growth_24h_pct,
    cast("stakers_growth_7D" as numeric)             as stakers_growth_7d_pct,
    cast("stakers_growth_30D" as numeric)            as stakers_growth_30d_pct
from {{ source('plume', 'raw_plume_staking') }}
