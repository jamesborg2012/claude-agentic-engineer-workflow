export function createBasket() {
  const items = [];
  return {
    add(productId) {
      items.push(productId);
    },
    count() {
      return items.length;
    },
  };
}
