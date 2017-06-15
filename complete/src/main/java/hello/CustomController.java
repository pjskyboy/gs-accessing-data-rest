package hello;

import io.swagger.annotations.ApiParam;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Slf4j
public class CustomController {

    @RequestMapping(value = "/custom", method = RequestMethod.GET)
    public String custom(@EnumParamApi @ApiParam(value="EnumParam values", type = "string")
                             @RequestParam String parameter1) {

        log.debug("parameter1={}", parameter1);
        EnumParam enumParam = EnumParam.instanceOf(parameter1);
        return "custom";
    }
}