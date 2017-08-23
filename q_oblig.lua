t_sleep = 5000 --���� �� 5 ������

aggressive = false --���������� - ������ ������ ������� ���� ������ ����� �������, ���� ����� ����������

orders = {} --������

is_run = true --������ ��������


function OnInit(script_path)
	--������������� ������� ��� �������
	--�������� ���������
	t_account = "L01+00000F00" --���� �� ����
	t_client_code = "00000" --��� �������
	t_sec_code = "xxxxxx" --��� �����������
	t_sec_class_code = "EQOB" --��� ������ �����������
	t_firm_id = "MC0099900000" -- ���� //���������� �������� -> ������� �����

	--���������� ��������� �����������
	local sec_param = getSecurityInfo(t_sec_class_code, t_sec_code)
	lot_size = sec_param.lot_size
	price_step = sec_param.min_price_step

	--������� ����� � �����!!!
	t_q = 1
	
	--�������� ������
	BUY_LEVEL = 99.05
	SELL_LEVEL = 99.40

	if BUY_LEVEL>SELL_LEVEL then
		message("������� ������������ ������!")
		is_run = false
		return false
	end

	--������� ������, ��� ������� �� ������ ��� ��� ����� �����
	BIG_SIZE = 7

	message("������ �������.")
end


function best_bid(sec_class_code, sec_code)
	--������� ����������� ������ ���� ������ �� �������
	local tb = getQuoteLevel2(sec_class_code, sec_code)
	return {
		["price"] = tonumber(tb.bid[math.ceil(tonumber(tb.bid_count))].price),
		["quantity"] = math.ceil(tonumber(tb.bid[math.ceil(tonumber(tb.bid_count))].quantity))
	}
end


function best_offer(sec_class_code, sec_code)
	--������� ����������� ������ ���� ������ �� �������
	local tb = getQuoteLevel2(sec_class_code, sec_code)
	return {
		["price"] = tonumber(tb.offer[1].price),
		["quantity"] = math.ceil(tonumber(tb.offer[1].quantity))
	}
end


function buy(price, quantity)
	--������� ������� �� �������� ����
	local quantity = quantity or t_q
	message("���������� *�������*\n��� �: "..quantity.." �� ���� "..price)
	local tr_res = transaction("B", price, quantity)
	message("��������� ���������� *�������*:\n"..tr_res)
end


function sell(price, quantity)
	--������� ������� �� �������� ����
	local quantity = quantity or t_q
	message("���������� *�������*\n��� �: "..quantity.." �� ���� "..price)
	local tr_res = transaction("S", price, quantity)
	message("��������� ���������� *�������*:\n"..tr_res)
end


function transaction(operation, price, quantity)
	--���������� ������� ��� ���������� �������/������
	local transaction = {
		["CLASSCODE"] = t_sec_class_code,
		["SECCODE"] = t_sec_code,
		["ACTION"] = "NEW_ORDER",
		["ACCOUNT"] = t_account,
		["CLIENT_CODE"] = t_client_code,
		["TYPE"] = "L",
		["OPERATION"] = operation,
		["QUANTITY"] = tostring(quantity),
		["PRICE"] = tostring(price),
		["TRANS_ID"] = "1"
	}
	result = sendTransaction(transaction)
	return result
end


function logic()
	--�������, ����������� �������� ������ ������

	--��������� ���������� � ����������� �������� �������
	orders = get_orders(t_sec_class_code, t_sec_code)

	--������ ������� ������� � �������
	local buy_level, sell_level = buy_sell_level()
	--������ ����������� ��������� �������
	local can_buy, can_sell = can_trade_lots()
	--����������� �����
	local q = 0
	--������� ���������� ����� (� �����)
	local p_b = paper_balance()

	if #orders.buy==0 and #orders.sell==0 then
		--���� ������ ��� ������
		q = math.min(can_sell, math.abs(p_b))
		if q>0 then
			--�������, ���� ���� ��� ���������
			sell(sell_level, q)
		end
		
		q = math.min(can_buy, math.abs(t_q-p_b))
		if q>0 then
			--��������, ���� ���� �� ��� ��������
			buy(buy_level, q)
		end
	else
		--�������� ������ �� �������
		local order = {}
		for i=1,#orders.buy do
			order = orders.buy[i]
			if (order.price ~= buy_level) then--or (order.balance ~= q) then
				cancel_order(order)
			end
		end
		--�������� ������ �� �������
		for i=1,#orders.sell do
			order = orders.sell[i]
			if (order.price ~= sell_level) then--or (order.balance ~= q) then
				message("sell_level: "..sell_level.."\nprice: "..order.price)
				sleep(350)
				cancel_order(order)
			end
		end
		--�������������� ������ ��� �������������
		--��������� ������� �������� ������
		orders = get_orders(t_sec_class_code, t_sec_code)
		--��������� ��������� ������
		can_buy, can_sell = can_trade_lots()
		--��������� ������� ���������� ����� (� �����)
		p_b = paper_balance()
		q = math.min(can_buy, math.abs(t_q-p_b))
		if q>0 then
			if #orders.buy==0 then
				buy(buy_level, q)
			end
		end
		q = math.min(can_sell, math.abs(p_b))
		if q>0 then
			if #orders.sell==0 then
				sell(sell_level, q)
			end
		end
	end
end


function cancel_order(order)
	--���������� ������� ��� ���������� �������/������
	local transaction = {
		["CLASSCODE"] = t_sec_class_code,
		["SECCODE"] = t_sec_code,
		["ACTION"] = "KILL_ORDER",
		["ORDER_KEY"] = tostring(order.order_num),
		["TRANS_ID"] = "1"
	}
	result = sendTransaction(transaction)
	message("cancel order #"..order.order_num.."\n"..result, 1)
end


function cancel_all_orders()
	local orders = get_orders(t_sec_class_code, t_sec_code)

	if orders.buy and #orders.buy>0 then
		for i=1,#orders.buy do
			order = orders.buy[i]
			cancel_order(order)
		end
	end
	
	if orders.sell and #orders.sell>0 then
		for i=1,#orders.sell do
			order = orders.sell[i]
			cancel_order(order)
		end
	end
end


function buy_sell_level()
	--��������� ������ � ����������� �� ������� ������
	local bbp = best_bid(t_sec_class_code, t_sec_code)["price"]
	local bbq = best_bid(t_sec_class_code, t_sec_code)["quantity"]
	local bop = best_offer(t_sec_class_code, t_sec_code)["price"]
	local boq = best_offer(t_sec_class_code, t_sec_code)["quantity"]
	local orders = get_orders(t_sec_class_code, t_sec_code)
	local buy_level = nil
	local sell_level = nil

	--��������� ������� �������
	if #orders.buy>0 then
		for i=1,#orders.buy do
			order = orders.buy[i]
			if not (order.price==bbp) then
				buy_level = math.min(bbp+price_step, BUY_LEVEL)
			else
				buy_level = bbp --���� ���� ������ ������, �� �� ���� ������ ��������
				break
			end
		end
	else
		if bbp<BUY_LEVEL then
			if bbq>=BIG_SIZE then
				buy_level = bbp+price_step
			elseif aggressive then
				buy_level = bbp+price_step
			else
				buy_level = bbp
			end
		else
			buy_level = BUY_LEVEL
		end
	end

	--��������� ������� �������
	if #orders.sell>0 then
		--���� ���� ���� ������ �� �������, �� �� ���� ������������� � ����� �����
		for i=1,#orders.sell do
			order = orders.sell[i]
			if not (order.price==bop) then
				sell_level = math.max(bop-price_step, SELL_LEVEL)
			else
				sell_level = bop --���� ���� ������ ������, �� �� ���� ������ ��������
				break
			end
		end
	else
		if bop>SELL_LEVEL then
			if boq>=BIG_SIZE then
				sell_level = bop-price_step
			elseif aggressive then
				sell_level = bop-price_step
			else
				sell_level = bop
			end
		else
			sell_level = SELL_LEVEL
		end
	end

	return buy_level, sell_level
end


function main()
	while is_run do
		sleep(t_sleep)
		logic()
	end
	message("������ ����������.")
end


function OnStop(stop_flag)
	--��������� �������
	message("������ ���������������...")
	is_run = false
end

function get_orders(sec_class_code, sec_code)
	--������� ��������� ����������� ������ �� �����������
	local orders = {
		["buy"] = {},
		["sell"] = {},
	}
	local n_own = 0
	local n_orders = getNumberOf("orders") --���-�� ������
	for i=0,n_orders-1 do
		order = getItem("orders", i)
		if bit.test(order["flags"], 0) then --���� ������ �������
			if not bit.test(order["flags"], 2) then --���� ������ �� �������
				orders.buy[#orders.buy+1] = order --��������� ��
			else --�� ���� �� �� �������, �� ��-������ �� �������
				orders.sell[#orders.sell+1] = order --��������� ��
			end
		end
	end
	return orders
end


function can_trade_lots()
	local bs_info = getBuySellInfo (t_firm_id, t_client_code, t_sec_class_code, t_sec_code, 0)
	local cb = math.ceil(tonumber(bs_info.can_buy_own)/lot_size)
	local cs = math.ceil(tonumber(bs_info.can_sell_own)/lot_size)
	return cb, cs
end


function paper_balance()
	--���������� ���������� ����� � �����
	return math.ceil(getDepo(t_client_code, t_firm_id, t_sec_code, t_account)["depo_current_balance"]/lot_size)
end
