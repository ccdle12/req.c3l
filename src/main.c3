module req;
import std::io;
import tora;

fn int main(String[] args)
{
    Response res = req::get("http://echo.free.beeceptor.com", accept: "*/*", lang: "", encoding: "", content_type: "")!!;
    //Response res = req::get("http://reqbin.com/echo", accept: "*/*", lang: "", encoding: "", content_type: "")!!;

	return 0;
}
