WITH a AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.created_at::date AS d,
        o.total_amount,
        o.discount_amount,
        o.channel,
        o.status
    FROM orders o
    WHERE o.created_at >= DATE '2024-01-01'
),
b AS (
    SELECT
        i.order_id,
        i.product_id,
        i.quantity,
        i.unit_price,
        i.category
    FROM order_items i
),
c AS (
    SELECT
        r.order_id,
        r.refund_id,
        r.refund_amount,
        r.created_at::date AS refund_d
    FROM refunds r
),
d AS (
    SELECT
        s.customer_id,
        s.session_id,
        s.session_start::date AS session_d,
        s.device_type,
        s.source
    FROM sessions s
),
e AS (
    SELECT
        m.customer_id,
        m.event_id,
        m.event_time::date AS event_d,
        m.event_type,
        m.campaign_id
    FROM marketing_events m
),
f AS (
    SELECT
        p.customer_id,
        p.payment_id,
        p.payment_time::date AS payment_d,
        p.amount AS payment_amount,
        p.payment_method
    FROM payments p
),
g AS (
    SELECT
        a.d,
        a.order_id,
        a.customer_id,
        a.total_amount,
        a.discount_amount,
        a.channel,
        a.status,
        b.product_id,
        b.quantity,
        b.unit_price,
        b.category,
        c.refund_id,
        c.refund_amount,
        d.session_id,
        d.device_type,
        d.source,
        e.event_id,
        e.event_type,
        e.campaign_id,
        f.payment_id,
        f.payment_amount,
        f.payment_method
    FROM a
    LEFT JOIN b
        ON a.order_id = b.order_id
    LEFT JOIN c
        ON a.order_id = c.order_id
    LEFT JOIN d
        ON a.customer_id = d.customer_id
    LEFT JOIN e
        ON a.customer_id = e.customer_id
    LEFT JOIN f
        ON a.customer_id = f.customer_id
),
h AS (
    SELECT
        d,
        channel,
        category,
        device_type,
        source,
        campaign_id,
        payment_method,
        COUNT(order_id) AS orders,
        COUNT(customer_id) AS customers,
        SUM(quantity) AS units,
        SUM(total_amount) AS revenue,
        SUM(discount_amount) AS discounts,
        SUM(refund_amount) AS refunds,
        AVG(total_amount) AS aov,
        AVG(payment_amount) AS avg_payment,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN event_type = 'email_open' THEN 1 ELSE 0 END) AS email_opens,
        SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) AS clicks,
        SUM(CASE WHEN refund_id IS NOT NULL THEN 1 ELSE 0 END) AS refunded_orders
    FROM g
    GROUP BY 1,2,3,4,5,6,7
),
i AS (
    SELECT
        customer_id,
        MAX(d) AS last_order_d,
        SUM(total_amount) AS lifetime_value,
        COUNT(order_id) AS lifetime_orders
    FROM g
    GROUP BY 1
),
j AS (
    SELECT
        g.d,
        g.order_id,
        g.customer_id,
        g.channel,
        g.category,
        g.device_type,
        g.source,
        g.campaign_id,
        g.payment_method,
        g.total_amount,
        g.discount_amount,
        g.refund_amount,
        g.quantity,
        g.status,
        i.last_order_d,
        i.lifetime_value,
        i.lifetime_orders,
        CASE WHEN i.last_order_d > g.d THEN 1 ELSE 0 END AS retained_30d,
        CASE WHEN g.refund_amount > 0 THEN 1 ELSE 0 END AS target
    FROM g
    LEFT JOIN i
        ON g.customer_id = i.customer_id
)
SELECT
    j.d,
    j.channel,
    j.category,
    j.device_type,
    j.source,
    j.campaign_id,
    j.payment_method,
    COUNT(j.order_id) AS rows_seen,
    COUNT(j.customer_id) AS buyers,
    SUM(j.quantity) AS items_sold,
    SUM(j.total_amount) AS gross_sales,
    SUM(j.discount_amount) AS total_discount,
    SUM(j.refund_amount) AS total_refund,
    AVG(j.total_amount) AS avg_order_value,
    AVG(j.lifetime_value) AS avg_customer_value,
    AVG(j.lifetime_orders) AS avg_customer_orders,
    AVG(j.retained_30d) AS retention_rate,
    AVG(j.target) AS refund_rate,
    SUM(CASE WHEN j.status = 'completed' THEN 1 ELSE 0 END) AS completed
FROM j
GROUP BY 1,2,3,4,5,6,7
ORDER BY 1,2,3,4,5,6,7;
