import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const MAX_ORDER_ID = 100000; // pre-seeded orders

const successCount = new Counter('success_total');
const failCount = new Counter('fail_total');

export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: __ENV.VUS ? parseInt(__ENV.VUS) : 50 },
        { duration: '30s', target: __ENV.VUS ? parseInt(__ENV.VUS) : 50 },
        { duration: '10s', target: 0 },
      ],
    },
  },
};

// 50% GET single, 30% GET list, 20% POST create
export default function () {
  const roll = Math.random();

  if (roll < 0.5) {
    getOrder();
  } else if (roll < 0.8) {
    listOrders();
  } else {
    createOrder();
  }
}

function getOrder() {
  const id = Math.floor(Math.random() * MAX_ORDER_ID) + 1;
  const res = http.get(`${BASE_URL}/orders/${id}`, { tags: { name: 'GET /orders/:id' } });
  const ok = check(res, { 'GET /orders/:id 200': (r) => r.status === 200 });
  ok ? successCount.add(1) : failCount.add(1);
}

function listOrders() {
  const userId = Math.floor(Math.random() * 100) + 1;
  const limit = 20;
  const res = http.get(`${BASE_URL}/orders?user_id=${userId}&limit=${limit}`);
  const ok = check(res, { 'GET /orders?user_id 200': (r) => r.status === 200 });
  ok ? successCount.add(1) : failCount.add(1);
}

function createOrder() {
  const payload = JSON.stringify({
    user_id: Math.floor(Math.random() * 100) + 1,
    product_id: Math.floor(Math.random() * 100) + 1,
    quantity: Math.floor(Math.random() * 5) + 1,
  });
  const params = { headers: { 'Content-Type': 'application/json' } };
  const res = http.post(`${BASE_URL}/orders`, payload, params);
  const ok = check(res, { 'POST /orders 201': (r) => r.status === 201 });
  ok ? successCount.add(1) : failCount.add(1);
}