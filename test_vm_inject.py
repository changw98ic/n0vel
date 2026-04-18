#!/usr/bin/env python3
"""通过 VM Service WebSocket 调用测试扩展，驱动 AI 对话创建小说元素"""
import json, sys, time
import websocket

VM_WS = sys.argv[1] if len(sys.argv) > 1 else "ws://127.0.0.1:54268/bgXDAD6j2M4=/ws"
req_id = 0

def vm_call(method, params=None):
    global req_id
    req_id += 1
    msg = {"jsonrpc": "2.0", "id": str(req_id), "method": method, "params": params or {}}
    ws = websocket.create_connection(VM_WS, timeout=30)
    ws.send(json.dumps(msg))
    raw = ws.recv()
    ws.close()
    return json.loads(raw)

def get_isolate():
    r = vm_call("getVM")
    isolates = r.get("result", {}).get("isolates", [])
    return isolates[0]["id"] if isolates else None

def call_ext(iso_id, ext_name, params=None):
    """通过 isolate 的 extension RPC 直接调用"""
    p = {"isolateId": iso_id}
    if params:
        p.update(params)
    return vm_call(ext_name, p)

def get_chat_state(iso_id):
    r = call_ext(iso_id, "ext.test.chatState")
    # result 可能是 dict 或 JSON string
    res = r.get("result")
    if isinstance(res, str):
        return json.loads(res)
    return res or {}

def wait_ai_response(iso_id, max_wait=60):
    """等待 AI 完成响应"""
    for i in range(max_wait // 2):
        time.sleep(2)
        st = get_chat_state(iso_id)
        if not st:
            continue
        is_gen = st.get("isGenerating", True)
        msg_count = st.get("messageCount", 0)
        tools = st.get("toolResults", [])

        if tools:
            for t in tools:
                s = "OK" if t.get("success") else "FAIL"
                print(f"    Tool [{s}]: {t.get('summary', '')}")

        if not is_gen and msg_count > 0:
            last = st.get("lastMessage", "")[:300]
            print(f"  AI response ({msg_count} msgs): {last}...")
            if st.get("pendingEntity"):
                print(f"  Pending entity: {st['pendingEntity']}")
            return st
        if i % 5 == 0 and i > 0:
            print(f"    ... waiting (gen={is_gen}, msgs={msg_count})")
    print("  TIMEOUT waiting for AI response")
    return {}

def main():
    print("=== AI Chat Injection Test ===\n")

    iso_id = get_isolate()
    if not iso_id:
        print("ERROR: no isolate found")
        return
    print(f"[OK] Isolate: {iso_id}")

    # Step 1: Navigate to AI chat
    print("\n--- Step 1: Navigate to AI chat ---")
    r = call_ext(iso_id, "ext.test.navigate", {"tab": "AI \u52a9\u624b"})
    print(f"  Result: {json.dumps(r, ensure_ascii=False)[:200]}")
    time.sleep(2)

    # Step 2: Create novel via chat
    print("\n--- Step 2: Create novel via AI chat ---")
    r = call_ext(iso_id, "ext.test.chat", {
        "message": "Create a new novel called 'Test Galaxy Expedition', sci-fi genre, about human interstellar colonization"
    })
    print(f"  Send: {json.dumps(r, ensure_ascii=False)[:200]}")
    wait_ai_response(iso_id)

    # Step 3: Create character
    print("\n--- Step 3: Create character via AI chat ---")
    r = call_ext(iso_id, "ext.test.chat", {
        "message": "Create a character: Lin Xingchen, male, 28, starship captain, calm and decisive"
    })
    print(f"  Send: {json.dumps(r, ensure_ascii=False)[:200]}")
    wait_ai_response(iso_id)

    # Step 4: Create relationship
    print("\n--- Step 4: Create relationship via AI chat ---")
    r = call_ext(iso_id, "ext.test.chat", {
        "message": "Set up a relationship: Lin Xingchen and Su Waner are lovers"
    })
    print(f"  Send: {json.dumps(r, ensure_ascii=False)[:200]}")
    wait_ai_response(iso_id)

    # Final state
    print("\n--- Final State ---")
    st = get_chat_state(iso_id)
    print(f"  Total messages: {st.get('messageCount', 0)}")
    print(f"  Generating: {st.get('isGenerating', False)}")
    tools = st.get("toolResults", [])
    if tools:
        print(f"  Tool results: {len(tools)}")
        for t in tools:
            print(f"    [{'OK' if t.get('success') else 'FAIL'}] {t.get('summary', '')}")

    print("\n=== Test Complete ===")

if __name__ == "__main__":
    main()
