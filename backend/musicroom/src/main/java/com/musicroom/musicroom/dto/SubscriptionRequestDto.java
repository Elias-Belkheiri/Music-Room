package com.musicroom.musicroom.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class SubscriptionRequestDto {
    private String tier;
    private String duration; // "monthly" or "yearly"
}
