data=open(r"C:\Users\changw98\dev\writing_assistant\lib\core\services\ai\agent\agent_service.dart","rb").read()
try:
    data.decode("utf-8")
    print("Valid UTF-8: Yes")
except Exception as e:
    print(f"Valid UTF-8: No - {e}")
