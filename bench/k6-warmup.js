import http from 'k6/http';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const MAX_ORDER_ID = 100000;

// Short burst to warm Postgres buffer pool, connection pools, and runtime JIT.
// Results are discarded — this is not the measured run.
export const options = {
  vus: 10,
  duration: '10s',
  thresholds: {},
};

export default function () {
  const roll = Math.random();
  if (roll < 0.5) {
    http.get(`${BASE_URL}/orders/${Math.floor(Math.random() * MAX_ORDER_ID) + 1}`);
  } else if (roll < 0.8) {
    const userId = Math.floor(Math.random() * 100) + 1;
    http.get(`${BASE_URL}/orders?user_id=${userId}&limit=20`);
  } else {
    const payload = JSON.stringify({
      user_id: Math.floor(Math.random() * 100) + 1,
      product_id: Math.floor(Math.random() * 100) + 1,
      quantity: Math.floor(Math.random() * 5) + 1,
    });
    http.post(`${BASE_URL}/orders`, payload, {
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
