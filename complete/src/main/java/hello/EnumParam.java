package hello;

import org.springframework.expression.spel.ast.OpNE;

import java.util.Arrays;
import java.util.List;

/**
 * Created by pjsky on 15/06/2017.
 */
public enum EnumParam {
    ONE,
    TWO("Two"),
    THREE("3");

    private String display;

    EnumParam() {
        display = toString();
    }

    EnumParam(final String display) {
        this.display = display;
    }

    public String getDisplay() {
        return display;
    }

    public static EnumParam instanceOf(final String desired) {
        final EnumParam[] instance = new EnumParam[1];
        List<EnumParam> enumParams = Arrays.asList((EnumParam[])EnumParam.values());
        enumParams.forEach( (enumParam -> {
            if (enumParam.getDisplay().equals(desired)) {
                instance[0] = enumParam;
            }
        }
        ));
        return (null != instance[0]? instance[0] : EnumParam.valueOf(desired));
    }
}
