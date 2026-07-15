<?xml version="1.0" encoding="UTF-8"?>
<arcmark version="1.0.0">
  <diagram title="Commerce Domain">
    <nodes>
      <node id="n_customer" name="Customer" kind="entity" x="80" y="160">
        <field name="customerId" type="UUID"/>
        <field name="email" type="String"/>
        <field name="createdAt" type="DateTime"/>
      </node>
      <node id="n_order" name="Order" kind="entity" x="380" y="160">
        <field name="orderId" type="UUID"/>
        <field name="total" type="Decimal"/>
        <field name="status" type="String"/>
      </node>
      <node id="n_inventory" name="Inventory Service" kind="service" x="680" y="60">
        <field name="reserve" type="Command"/>
        <field name="release" type="Command"/>
      </node>
      <node id="n_payment" name="Payment Service" kind="service" x="680" y="260">
        <field name="charge" type="Command"/>
        <field name="refund" type="Command"/>
      </node>
      <node id="n_order_placed" name="Order Placed" kind="event" x="380" y="340">
        <field name="orderId" type="UUID"/>
        <field name="total" type="Decimal"/>
      </node>
    </nodes>
    <relationships>
      <relationship from="n_customer" to="n_order" type="places"/>
      <relationship from="n_order" to="n_inventory" type="reserves"/>
      <relationship from="n_order" to="n_payment" type="charges"/>
      <relationship from="n_order" to="n_order_placed" type="emits"/>
      <relationship from="n_order_placed" to="n_customer" type="notifies"/>
    </relationships>
  </diagram>
</arcmark>